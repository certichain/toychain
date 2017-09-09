From mathcomp.ssreflect
Require Import ssreflect ssrbool ssrnat eqtype ssrfun seq.
From mathcomp
Require Import path.
Require Import Eqdep pred prelude idynamic ordtype pcm finmap unionmap heap.
Require Import Blockchain Protocol Semantics States BlockchainProperties.
Set Implicit Arguments.
Unset Strict Implicit.
Unset Printing Implicit Defensive.

(***************************************************)
(*        Some useful facts about lists            *)
(***************************************************)

Lemma rem_neq {T: eqType} (x y :T) (ls : seq T) :
  x != y -> x \in ls -> x \in seq.rem y ls.
Proof.
move=>N; elim: ls=>//h ls Hi.
rewrite inE; case/orP=>//=.
- by move/eqP=>Z; subst h; move/negbTE: N=>->; rewrite inE eqxx.
by case: ifP=>//=N' /Hi; rewrite inE orbC=>->.
Qed.

Lemma in_rem_msg p0 p ms w :
  p0 \in inFlightMsgs w -> p0 <> p ->
  p0 \in ms ++ seq.rem p (let (_, inFlightMsgs, _) := w in inFlightMsgs).
Proof.
move=>iF0 E; rewrite mem_cat orbC; apply/orP; left.
case: (w) iF0=>ls ifM cM/= Hi.
suff N : (p0 != p) by rewrite (rem_neq N Hi).
by apply/negP=>/eqP Z; subst p0.
Qed.

Lemma ohead_hash b0 bt:
  b0 \in bt ->
  ohead [seq b <- bt | hashB b == hashB b0] = Some b0.
Proof.
elim: bt=>//=h bt Hi; rewrite inE; case/orP=>[/eqP Z|/Hi H]/=.
- by subst b0; rewrite eqxx.
by case: ifP=>C//=; move/eqP/hashB_inj: C=>->.
Qed.

(***************************************************)

(* Invariants of the execution regarding the blockchain *)
(* Properties *)

Definition has_chain (bc : Blockchain) (st : State) : Prop :=
  btChain (blockTree st) == bc.

Definition exists_and_holds (n : nid) (w : World) (cond : State -> Prop) :=
  exists (st : State),
    find n (localState w) = Some st /\ cond st.

Definition chain_sync_agreement (w w' : World) :=
  forall (n n' : nid) (bc bc' : Blockchain),
    holds n w (has_chain bc) ->
    reachable w w' ->
    holds n' w' (has_chain bc') ->
    size bc' == size bc ->
    bc == bc'.

Lemma has_chain_func n w (bc bc' : Blockchain):
  n \in dom (localState w) ->
  holds n w (has_chain bc) ->
  holds n w (has_chain bc') -> bc = bc'.
Proof.
case/um_eta=>st[Sf]_ nbc nbc'.
by move: (nbc st Sf) (nbc' st Sf)=>/eqP<-/eqP->.
Qed.

(* TODO: More complicated -- the "rollback" is no more than a contstant;
 *)

Lemma local_chain_grows_fork_step (w w' : World) q n bc bc':
  n \in dom (localState w) ->
  holds n w (has_chain bc) ->
  system_step w w' q ->
  holds n w' (has_chain bc') ->
  bc = bc' \/ (([bc <<< bc'] \/ fork bc bc') /\ bc' > bc).
Proof.
move=>D H1 S H2; move: (Coh_step S)=>C2.
case: S=>[[C]Z|p [n' prs bt pool] C _ _ F|
          proc t s1 C _ F].

(* 0 steps *)
- by subst w'; rewrite (has_chain_func D H1 H2); left.
(* Step is procedding a message *)

(* Receiving a message *)
- have E: (n' = (dst p)) by case:C=>_/(_ (dst p) _ F)/eqP. subst n'.

  (* Two sub-cases: (dst p) =? n *)
  case N : (n == dst p);[move/eqP:N=>N; subst n|]; last first.
  (* Message not to us: don't really care about the outcome of procMsg! *)
  + set pms := (procMsg _ _); case: pms=>st' ms Z; subst w'.
    rewrite /holds/= findU N/= in H2.
    by rewrite -(has_chain_func D H1 H2); left.
  rewrite [procMsg _ _ _]surjective_pairing=>Z;
  (* Avoiding premature unfolding. *)
  set Pm := nosimpl (procMsg _ _ _) in Z; subst w'.
  rewrite /holds/= findU eqxx/= (proj1 (C)) in H2.
  move/(H2 Pm.1): (erefl (Some Pm.1))=>{H2} H2.
  move: (H1 _ F)=>{H1 C2 F}/=H1.
  by apply: (@procMsg_bc_prefix_or_fork bc bc'
        {| id := dst p; peers := prs; blockTree := bt; txPool := pool |}
        (msg p) (ts q)); move/eqP: H2; move/eqP: H1.

(* Internal transition *)
(* Two sub-cases: proc =? n *)
case N : (n == proc);[move/eqP:N=>N; subst n|]; last first.
- set pms := (procInt _ _ _). case: pms=>st' ms Z. subst w'.
  rewrite /holds/= findU N/= in H2.
  by left; rewrite -(has_chain_func D H1 H2).

(* Another interesting part of the proof: n == proc.
   Consider all branches of procInt and proof the property for each one.
   Don't hesitate to introduce auxiliary lemmas. *)
rewrite [procInt _ _ _]surjective_pairing=>Z.
set Pi := nosimpl (procInt _ _ _) in Z; subst w'.
rewrite /holds/= findU eqxx/= (proj1 (C)) in H2. rewrite /holds F in H1.
have: (Some s1 = Some s1). by []. move=> eq. move: (H1 s1 eq)=>hbc. clear eq.
have: (Some Pi.1 = Some Pi.1). by []. move=> eq. move: (H2 Pi.1 eq)=>hbc'. clear eq.
rewrite /has_chain in hbc hbc'. move/eqP in hbc. move/eqP in hbc'.
specialize (procInt_bc_same_or_extension s1 t (ts q))=>/=.
case=>/=; rewrite -hbc -hbc'; first by left.
move=>Pf; right; split; first by left.
by move: Pf=>[] eh [] et ->; apply CFR_ext.
Qed.

(* Big-step case, proven by induction *)
Lemma local_chain_grows_fork (w w' : World) n bc bc':
  n \in dom (localState w) ->
  holds n w (has_chain bc) ->
  reachable w w' ->
  holds n w' (has_chain bc') ->
  bc = bc' \/ (([bc <<< bc'] \/ fork bc bc') /\ bc' > bc).
Proof.
move=>D H1 [m]R H2.
elim: m w' R bc' H2=>/=[w'<-|q m Hi w' [via][R S]] bc' H2.
- by left; move/(has_chain_func D H1 (bc':=bc')):H2=><-.
have D': n \in dom (localState via).
- suff R' : reachable w via by rewrite -(steps_nodes R').
  by exists m.
suff X : exists bc1, holds n via (has_chain bc1).
- case: X=>bc1 H; move: (Hi _ R _ H)=>P1.
  move: (local_chain_grows_fork_step D' H S H2)=>P2.
  case P1; case P2; clear P1 P2.
  - by move=><-<-; left.
  - case; case=> HH Gt Eq; right; split; rewrite -Eq in Gt; do? by [].
      by rewrite -Eq in HH; left.
      by rewrite -Eq in HH; right.

  - move=> Eq; case; case=> HH Gt; right; split; rewrite Eq in Gt; do? by [].
      by rewrite Eq in HH; left.
      by rewrite Eq in HH; right.

  (* Reasoning about forks *)
  case; case=> HH Gt; case; case=>HH' Gt';
  right; split; do? by move: (CFR_trans Gt Gt').
  (* --bc---bc1---bc' *)
  by left; move: (bc_spre_trans HH' HH).

  (*   /--bc
   * --
   *   \-----bc1---bc'
   *)
  by right; move: (bc_fork_prefix HH' (bc_spre_pre HH)).

  (*      /-- bc1                /---bc--bc1
   * --bc-               OR   ---
   *      \------- bc'           \-------------bc'
   *)
  case: (bc_relP bc bc').
  - by move/eqP=>Eq; subst bc'; contradict HH; move/norP=>[] _=>/norP;
       move/sprefixP in HH'; rewrite HH'=>/andP.
  - by move=>F; right.
  - by move=>Spf; left; apply/sprefixP.
  - by move/sprefixP=>Spf; move/sprefixP:(bc_spre_trans Spf HH')=>C;
       contradict HH; move/norP=>[] _=>/norP; rewrite C=>/andP.

  (*  /-bc                      /--bc-----------bc'
   *---------bc1          OR  --
   *      \---------bc'         \-------bc1
   * This is the most interesting case -- only provable if respecting CFR *)
  case: (bc_relP bc bc').
  - by move/eqP=>Eq; subst bc'; move: (CFR_trans Gt' Gt)=>C;
       contradict C; apply: CFR_nrefl.
  - by move=> F; right.
  - by move=>Spf; left; apply/sprefixP.
  - by move/sprefixP=>[b][ext] Eq; subst bc; move: (CFR_trans Gt Gt')=>C;
       move: (CFR_ext bc' b ext)=>C'; move: (CFR_excl C C').

rewrite /holds/has_chain.
move/um_eta: D';case; case=>id ps bt t [][->]_.
by exists (btChain (blockTree {|
    id := id; peers := ps; blockTree := bt; txPool := t |}))=>st[]<-.
Qed.

(*
* For simplicity, we assume all nodes are directly connected.
* This could be changed to incorporate a more realistic broadcast setting.
*)
Definition available (b : Block) n w :=
  exists (p : Packet),
    p \in inFlightMsgs w /\
    [\/ exists (peer : nid) (sh : seq Hash),
         msg p = InvMsg peer sh /\ dst p = n /\ hashB b \in sh,
       exists (hash : Hash),
         msg p = GetDataMsg n hash /\ src p = n /\ hashB b = hash /\
         holds (dst p ) w (fun st => b \in blockTree st) |
       msg p = BlockMsg b /\ dst p = n
    ].

Definition largest_chain (w : World) (bc : Blockchain) :=
   forall (n' : nid) (bc' : Blockchain),
    holds n' w (fun st => has_chain bc' st -> bc >= bc').

Definition GStable w :=
  inFlightMsgs w = [::] /\
  exists (bc : Blockchain), forall (n : nid),
    holds n w (has_chain bc).

Definition GSyncing w :=
  exists (bc : Blockchain) (n : nid),
  [/\ holds n w (has_chain bc),

   (* The canonical chain is the largest in the network *)
   largest_chain w bc,

   (* Applying blocks in flight will induce either the canonical
      chain or a smaller one. *)
   forall (n' : nid),
    let toN' := filter (fun p => dst p == n') (inFlightMsgs w) in
    let allBlocks := map (fun p => msg_block (msg p)) toN' in
    forall (blocks : seq Block),
      let bt' := fun st => foldr (fun b bt => btExtend bt b) (blockTree st) blocks in
      {subset blocks <= allBlocks} -> holds n' w (fun st => bc >= btChain (bt' st)) &

   (* All blocks (in any BlockTree) are available to every node *)
   forall (n1 n2 : nid) (b : Block),
     exists_and_holds n1 w (fun st => b \in blockTree st) ->
     holds n2 w (fun st => b \in blockTree st \/ available b n2 w)
].

Definition Inv (w : World) :=
  Coh w /\
  [\/ GStable w | GSyncing w].

Variable N : nat.

Lemma Inv_init : Inv (initWorld N).
Proof.
split; do? by apply Coh_init. left; split; do? by [].
exists (btChain (blockTree (Init 0)))=>/=.
rewrite /holds/has_chain; move=>n st; elim: N=>[|n' Hi].
  by move/find_some; rewrite dom0 inE.
  rewrite findUnL; last first.
  - case: validUn; rewrite ?um_validPt ?valid_initState//.
    move=>k; rewrite um_domPt !inE=>/eqP Z; subst k.
    by rewrite dom_initState mem_iota addnC addn1 ltnn andbC.
  - case: ifP=>//; rewrite um_domPt inE=>/eqP<-.
    by rewrite um_findPt; case=><-.
Qed.

Lemma Inv_step w w' q :
  Inv w -> system_step w w' q -> Inv w'.
Proof.
move=>Iw S; rewrite/Inv; split; first by apply: (Coh_step S).
case: S=>[|p st1 Cw _ iF Fw|proc t st1 Cw _ Fw]; first by elim=>_ <-; move: Iw=>[].
case: Iw=>_ [GStabW|GSyncW].
- by case GStabW=>noPackets; contradict iF; rewrite noPackets.
- case GSyncW=>can_bc [can_n] [] HHold HGt HInFlight HDiffAv.
  case P: (procMsg _ _ _)=>[stPm ms]; move=>->; right.
  (* The canonical chain is guaranteed to remain the same for any msg:
   *  - for non-block messages, this holds by procMsg_non_block_nc_btChain
   *  - for block messages, it holds by HInFlight *)
  exists can_bc; exists can_n; split.

  (* ... the original node still retains it *)
  + case Msg: (msg p)=>[|||b|||]; rewrite Msg in P;
    rewrite/holds/localState/has_chain=>st'; case X: (can_n == dst p); move/eqP in X;
    (* All cases except BlockMsg *)
    do? [subst can_n; rewrite findU (proj1 Cw)=>/=; case: ifP;
      by [move/eqP |
        (have: (forall b, msg p != BlockMsg b) by move=>b; rewrite Msg)=>H;
        move=>_ [] <-; move: (procMsg_non_block_nc_btChain st1 (ts q) H);
        rewrite Msg P=><-; apply (HHold st1 Fw)
      ]
    ];
    do? [rewrite findU (proj1 Cw)=>/=; case: ifP=>/=;
      by [move/eqP | move=>_ Fc; move: (HHold st' Fc)]
    ].
    (* BlockMsg *)
    rewrite findU (proj1 Cw)=>/=; case: ifP=>/=; last by move/eqP.
    move=>_ [] <-; rewrite [procMsg _ _ _] surjective_pairing in P; case: P.
    rewrite -X in Fw; move=><- _; specialize (HHold st1 Fw); rewrite/has_chain eq_sym.
    (* Specialize HInFlight for just BlockMsg b *)
    specialize (HInFlight can_n [:: b]).

    apply/eqP; case: HInFlight.
    * by move: (procMsg_block_btExtend st1 b (ts q))=>->.
    * move=>Con. contradict Con.
      rewrite/has_chain in HHold; move/eqP in HHold; rewrite -HHold.
      by apply btExtend_not_worse.

 (* ... it's still the largest *)
  + case Msg: (msg p)=>[|||b|||]; rewrite Msg in P;
    (* All cases except BlockMsg *)
    rewrite/holds/localState/has_chain=>n' bc' st';
    case X: (can_n == dst p); move/eqP in X;
    rewrite findU (proj1 Cw)=>/=; case: ifP=>/=; move/eqP;
    do? by [
      move=>_ Fc; move: (HGt n' bc' st' Fc) |
      (have: (forall b, msg p != BlockMsg b) by move=>b; rewrite Msg)=>H;
      move=>Eq [] <-; move: (procMsg_non_block_nc_btChain st1 (ts q) H);
      rewrite /has_chain Msg P=><-;
      rewrite -Eq in Fw=>Hc; move: (HGt n' bc' st1 Fw Hc)
    ].
    (* BlockMsg *)
    * move=>_ [] <-; rewrite [procMsg _ _ _] surjective_pairing in P; case: P.
      rewrite -X in Fw; move=><- _;
      specialize (HHold st1 Fw); rewrite/has_chain eq_sym.
      (* Specialize HInFlight for just BlockMsg b *)
      specialize (HInFlight can_n [:: b]).

      by move/eqP=>->; move: (procMsg_block_btExtend st1 b (ts q))=>->.
    * move=>Dst; subst n'; specialize (HGt (dst p) bc' st1 Fw).
      move=>[] Eq; subst stPm; have: (dst p = dst p) by []=>Obvs;
      move: (HInFlight p b (dst p) (btChain (blockTree st1)) iF Msg Obvs st1 Fw)=>H.
      clear Obvs; rewrite/has_chain; move/eqP=><-.
      by rewrite [procMsg _ _ _] surjective_pairing in P; case: P=><- _;
         move: (procMsg_block_btExtend st1 b (ts q))=>->.

(* the canonical chain can only change throught a MintT transition *)
(* TODO: refactor it into a lemma *)
- admit.
Admitted.