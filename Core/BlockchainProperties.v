From mathcomp.ssreflect
Require Import ssreflect ssrbool ssrnat eqtype ssrfun seq.
From mathcomp
Require Import path.
Require Import Eqdep pred prelude idynamic ordtype pcm finmap unionmap heap coding. 
Require Import Blockchain.
Set Implicit Arguments.
Unset Strict Implicit.
Unset Printing Implicit Defensive.

Section BlockchainOrder.

(* Strict version of the prefix *)
Definition is_strict_prefix {T: eqType} (bc bc' : seq T) :=
  exists b bc1, bc' = bc ++ (b :: bc1).

Notation "'[' bc1 '<<<' bc2 ']'" := (is_strict_prefix bc1 bc2).

Lemma isp_mt {T: eqType} (bc : seq T) : ~ is_strict_prefix bc [::].
Proof. by case=>b[bc1]; case: bc. Qed.

(* The corresponding checker *)
Fixpoint sprefixb {T: eqType} (s1 s2 : seq T) :=
  if s2 is y :: s2' then
    if s1 is x :: s1' then (x == y) && (sprefixb s1' s2')
    else true
  else false.         

Lemma sprefixP {T: eqType} (bc1 bc2 : seq T):
  reflect [bc1 <<< bc2] (sprefixb bc1 bc2).
Proof.
elim: bc2 bc1=>//=[|b2 bc2 Hi/=]bc1.
- case:bc1=>//=[|b1 bc1]; constructor 2=>//; apply: isp_mt.
case: bc1=>//[|b1 bc1]/=; first by constructor 1; exists b2, bc2.  
case X: (b1 == b2)=>/=; last first.
- constructor 2=>[[p]][bc']; rewrite cat_cons; case=>Z; subst b2.
  by rewrite eqxx in X.
- move/eqP: X=>X; subst b2.
case: Hi=>H; [constructor 1|constructor 2].
- by case:H=>x[xs]->; exists x, xs; rewrite cat_cons.  
case=>x[xs]; rewrite cat_cons; case=>Z; subst bc2; apply: H.
by exists x, xs.
Qed.

(* Decidable fork *)
Definition fork {T: eqType} (bc1 bc2 : seq T) :=
  ~~[|| sprefixb bc1 bc2, sprefixb bc2 bc1 | bc1 == bc2].


(* Non-strict prefix *)
Definition is_prefix {T :eqType} (bc bc' : seq T) :=
  exists bc1, bc' = bc ++ bc1.

Notation "'[' bc1 '<<=' bc2 ']'" := (is_prefix bc1 bc2).

Lemma bc_pre_refl {T :eqType} (bc : seq T) : [bc <<= bc].
Proof. by exists [::]; rewrite cats0. Qed.

Lemma bc_pre_trans {T :eqType} (bc1 bc2 bc3 : seq T) :
  [bc1 <<= bc2] -> [bc2 <<= bc3] -> [bc1 <<= bc3].
Proof.
case=> a1 H1 [a2] H2; subst bc2.
by rewrite -catA in H2; exists (a1 ++ a2).
Qed.

Lemma bc_pre_gt bc bc' :
  [bc <<= bc'] -> bc' > bc.
Proof.
by case=>ext=>eq; rewrite eq; apply CFR_ext.
Qed.

Lemma bc_prefix_mt {T :eqType} (bc : seq T) : [bc <<= [::]] -> bc == [::].
Proof. by case: bc=>//b bc[x]. Qed.
 
Fixpoint prefixb {T: eqType} (s1 s2 : seq T) :=
  if s2 is y :: s2' then
    if s1 is x :: s1' then (x == y) && (prefixb s1' s2')
    else true
  else s1 == [::].         

Lemma bc_prefixb_mt {T :eqType} (bc : seq T) : prefixb bc [::] -> bc == [::].
Proof. by case: bc=>//b bc[x]. Qed.

Lemma prefixP {T :eqType} (bc1 bc2 : seq T):
  reflect [bc1 <<= bc2] (prefixb bc1 bc2).
Proof.
elim: bc2 bc1=>//=[|b2 bc2 Hi/=]bc1.
- case B: (prefixb bc1 [::]); [constructor 1|constructor 2].
  + by move/bc_prefixb_mt/eqP: B=>->; exists [::].
  by case: bc1 B=>//b bc1/=_[?].
case: bc1=>//[|b1 bc1]; first by constructor 1; exists (b2::bc2). 
case X: (b1 == b2)=>/=; rewrite X/=; last first.
- constructor 2=>[[p]]; rewrite cat_cons; case=>Z; subst b2.
  by rewrite eqxx in X.
- move/eqP: X=>X; subst b2.
case: Hi=>H; [constructor 1|constructor 2].
- by case:H=>x->; exists x; rewrite cat_cons.  
case=>t; rewrite cat_cons; case=>Z; subst bc2; apply: H.
by exists t.
Qed.

Lemma prb_equiv {T: eqType} (bc1 bc2 : seq T) :
  prefixb bc1 bc2 = (bc1 == bc2) || (sprefixb bc1 bc2).
Proof.
apply/Bool.eq_iff_eq_true; split.
- move/prefixP=>[x]->; case: x=>[|x xs]; first by rewrite cats0 eqxx.
  by apply/orP; right; apply/sprefixP; exists x, xs.
(* TODO: george, please, finish this as an exercise! *)
admit.
Admitted.
  
End BlockchainOrder.

Notation "'[' bc1 '<<=' bc2 ']'" := (is_prefix bc1 bc2).
Notation "'[' bc1 '<<<' bc2 ']'" := (is_strict_prefix bc1 bc2).

Section Forks.

Lemma bc_fork_neq {T: eqType} (bc bc' : seq T) :
  fork bc bc' -> bc != bc'.
Proof.
move=>H; apply/negbT/negP=>Z; move/eqP:Z=>Z; subst bc'.
by case/orP: H; right; rewrite orbC eqxx. 
Qed.

Lemma bc_fork_sym {T: eqType} (bc bc' : seq T) :
  fork bc bc' -> fork bc' bc.
Proof.
by rewrite/fork; rewrite eq_sym orbCA.
Qed.

Lemma bc_fork_prefix {T: eqType} (a b c : seq T) :
  fork a b -> [b <<= c] -> fork a c.
Proof.
move/orP=>H1 H2; apply/negP=>/orP H3; apply: H1.
case:H3.
Admitted.  
(* TODO: redo me for the new fork definition! *)

(* rewrite/fork. elim=>H2 H1[x] H3. subst c. *)
(* elim: x b H1 H2=>[|x xs Hi] b H1 H2. *)
(* - by rewrite cats0. *)
(* rewrite -cat_rcons. apply: Hi=>H. *)
(* - by apply: H1; case: H=>z->; rewrite cat_rcons; eexists _. *)
(* - rewrite/is_prefix in H H1 H2. *)
(* case: H=>z. elim/last_ind: z=>[|zs z Hi]. *)
(* - by rewrite cats0=>Z; subst a; apply: H1; exists [:: x]; rewrite cats1. *)
(* rewrite -rcons_cat=>/eqP. rewrite eqseq_rcons. move/andP=>[/eqP Z]/eqP Z'. *)
(* by subst x b; apply: H2; exists zs. *)

Axiom btChain_fork :
  forall (bt : BlockTree) (bc : Blockchain) (b : Block),
  let: bc' := btChain (btExtend bt b) in
    btChain bt = bc ->
    b \notin bc ->
    prevBlockHash (bcLast bc') != hashB (bcLast bc) ->
    fork bc bc'.

End Forks.