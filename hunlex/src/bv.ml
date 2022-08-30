(*
 * Multi ordered Bit vectors with count
 * Copyright (C) 1999 Jean-Christophe FILLIATRE
 * 
 * This software is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Library General Public
 * License version 2, as published by the Free Software Foundation.
 * 
 * This software is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
 * 
 * See the GNU Library General Public License version 2 for more details
 * (enclosed in the file LGPL).
 *)

(*i $Id: bv.ml,v 1.1.1.1 2010-10-29 09:30:47 root Exp $ i*)

(*s Bit vectors. The interface and part of the code are borrowed from the 
    [Array] module of the ocaml standard library (but things are simplified
    here since we can always initialize a bit vector). This module also
    provides bitwise operations. *)

(*s We represent a bit vector by a vector of integers (field [bits]),
    and we keep the information of the size of the bit vector since it
    can not be found out with the size of the array (field [length]). *)

type t = {
    length : int;
    bits   : int array;
    mutable level  : int;
    mutable modif  : bool
  }

let length v = v.length

let compare bv1 bv2 = 
  let a1, a2 = bv1.bits, bv2.bits in
  let i = ref 0 in 
  let diff = ref 0 in
  let n = Array.length a1 in 
  while !i < n && !diff = 0 do diff := a1.(!i) - a2.(!i); incr i done;
  !diff

let hash = Hashtbl.hash

let equal = (=)

(*s Each element of the array is an integer containing [bpi] bits, where
    [bpi] is determined according to the machine word size. Since we do not
    use the sign bit, [bpi] is 30 on a 32-bits machine and 62 on a 64-bits
    machines. We maintain the following invariant:
    {\em The unused bits of the last integer are always 
    zeros.} This is ensured by [create] and maintained in other functions
    using [normalize]. [bit_j], [bit_not_j], [low_mask] and [up_mask]
    are arrays used to extract and mask bits in a single integer. *)

let bpi = Sys.word_size - 2

let max_length = Sys.max_array_length * bpi

let bit_j = Array.init bpi (fun j -> 1 lsl j)
let bit_not_j = Array.init bpi (fun j -> max_int - bit_j.(j))

let low_mask = Array.create (succ bpi) 0
let _ = 
  for i = 1 to bpi do low_mask.(i) <- low_mask.(i-1) lor bit_j.(pred i) done

let keep_lowest_bits a j = a land low_mask.(j)

let high_mask = Array.init (succ bpi) (fun j -> low_mask.(j) lsl (bpi-j))

let keep_highest_bits a j = a land high_mask.(j)

(*s Creating and normalizing a bit vector is easy: it is just a matter of
    taking care of the invariant. Copy is immediate. *)

let create n b =
  let initv = if b then max_int else 0 in
  let r = n mod bpi in
  let level = if b then 0 else n in
  if r = 0 then
    { length = n; bits = Array.create (n / bpi) initv; modif = false; level = level }
  else begin
    let s = n / bpi in
    let b = Array.create (succ s) initv in
    b.(s) <- b.(s) land low_mask.(r);
    { length = n; bits = b; modif = false; level = level }
  end
    
let make = create

let normalize v =
  let r = v.length mod bpi in
  if r > 0 then
    let b = v.bits in
    let s = Array.length b in
    b.(s-1) <- b.(s-1) land low_mask.(r)

let copy v = { length = v.length; bits = Array.copy v.bits; modif = v.modif; level = v.level }

(*s Access and assignment. The [n]th bit of a bit vector is the [j]th
    bit of the [i]th integer, where [i = n / bpi] and [j = n mod
    bpi]. Both [i] and [j] and computed by the function [pos].
    Accessing a bit is testing whether the result of the corresponding
    mask operation is non-zero, and assigning it is done with a
    bitwiwe operation: an {\em or} with [bit_j] to set it, and an {\em
    and} with [bit_not_j] to unset it. *)

let pos n = 
  let i = n / bpi and j = n mod bpi in
  if j < 0 then (i - 1, j + bpi) else (i,j)

let unsafe_get v n =
  let (i,j) = pos n in 
  ((Array.unsafe_get v.bits i) land (Array.unsafe_get bit_j j)) > 0

let unsafe_set v n b =
  let (i,j) = pos n in
  v.modif <- true;
  if b then
    Array.unsafe_set v.bits i 
      ((Array.unsafe_get v.bits i) lor (Array.unsafe_get bit_j j))
  else 
    Array.unsafe_set v.bits i 
      ((Array.unsafe_get v.bits i) land (Array.unsafe_get bit_not_j j))

(*s The corresponding safe operations test the validiy of the access. *)

let get v n =
  if n < 0 or n >= v.length then invalid_arg "Bitv.get";
  let (i,j) = pos n in 
  ((Array.unsafe_get v.bits i) land (Array.unsafe_get bit_j j)) > 0

let set v n b =
  if n < 0 or n >= v.length then invalid_arg "Bitv.set";
  let (i,j) = pos n in
  v.modif <- true;
  if b then
    Array.unsafe_set v.bits i
      ((Array.unsafe_get v.bits i) lor (Array.unsafe_get bit_j j))
  else
    Array.unsafe_set v.bits i
      ((Array.unsafe_get v.bits i) land (Array.unsafe_get bit_not_j j))

(*s [init] is implemented naively using [unsafe_set]. *)

let init n f =
  let v = create n false in
  for i = 0 to pred n do
    unsafe_set v i (f i)
  done;
  v

(*s Handling bits by packets is the key for efficiency of functions
    [append], [concat], [sub] and [blit]. 
    We start by a very general function [blit_bits a i m v n] which blits 
    the bits [i] to [i+m-1] of a native integer [a] 
    onto the bit vector [v] at index [n]. It assumes that [i..i+m-1] and
    [n..n+m-1] are respectively valid subparts of [a] and [v]. 
    It is optimized when the bits fit the lowest boundary of an integer 
    (case [j == 0]). *)

let blit_bits a i m v n =
  let (i',j) = pos n in
  if j == 0 then
    Array.unsafe_set v i'
      ((keep_lowest_bits (a lsr i) m) lor
       (keep_highest_bits (Array.unsafe_get v i') (bpi - m)))
  else 
    let d = m + j - bpi in
    if d > 0 then begin
      Array.unsafe_set v i'
	(((keep_lowest_bits (a lsr i) (bpi - j)) lsl j) lor
	 (keep_lowest_bits (Array.unsafe_get v i') j));
      Array.unsafe_set v (succ i')
	((keep_lowest_bits (a lsr (i + bpi - j)) d) lor
	 (keep_highest_bits (Array.unsafe_get v (succ i')) (bpi - d)))
    end else 
      Array.unsafe_set v i'
	(((keep_lowest_bits (a lsr i) m) lsl j) lor
	 ((Array.unsafe_get v i') land (low_mask.(j) lor high_mask.(-d))))

(*s [blit_int] implements [blit_bits] in the particular case when
    [i=0] and [m=bpi] i.e. when we blit all the bits of [a]. *)

let blit_int a v n =
  let (i,j) = pos n in
  if j == 0 then
    Array.unsafe_set v i a
  else begin
    Array.unsafe_set v i 
      ( (keep_lowest_bits (Array.unsafe_get v i) j) lor
       ((keep_lowest_bits a (bpi - j)) lsl j));
    Array.unsafe_set v (succ i)
      ((keep_highest_bits (Array.unsafe_get v (succ i)) (bpi - j)) lor
       (a lsr (bpi - j)))
  end

(*s When blitting a subpart of a bit vector into another bit vector, there
    are two possible cases: (1) all the bits are contained in a single integer
    of the first bit vector, and a single call to [blit_bits] is the
    only thing to do, or (2) the source bits overlap on several integers of
    the source array, and then we do a loop of [blit_int], with two calls
    to [blit_bits] for the two bounds. *)

let unsafe_blit v1 ofs1 v2 ofs2 len =
  let (bi,bj) = pos ofs1 in
  let (ei,ej) = pos (ofs1 + len - 1) in
  if bi == ei then
    blit_bits (Array.unsafe_get v1 bi) bj len v2 ofs2
  else begin
    blit_bits (Array.unsafe_get v1 bi) bj (bpi - bj) v2 ofs2;
    let n = ref (ofs2 + bpi - bj) in
    for i = succ bi to pred ei do
      blit_int (Array.unsafe_get v1 i) v2 !n;
      n := !n + bpi
    done;
    blit_bits (Array.unsafe_get v1 ei) 0 (succ ej) v2 !n
  end

let blit v1 ofs1 v2 ofs2 len =
  if len < 0 or ofs1 < 0 or ofs1 + len > v1.length
             or ofs2 < 0 or ofs2 + len > v2.length
  then invalid_arg "Bitv.blit";
  unsafe_blit v1.bits ofs1 v2.bits ofs2 len

(*s Extracting the subvector [ofs..ofs+len-1] of [v] is just creating a
    new vector of length [len] and blitting the subvector of [v] inside. *)

let sub v ofs len =
  if ofs < 0 or len < 0 or ofs + len > v.length then invalid_arg "Bitv.sub";
  let r = create len false in
  unsafe_blit v.bits ofs r.bits 0 len;
  r

(*s The concatenation of two bit vectors [v1] and [v2] is obtained by 
    creating a vector for the result and blitting inside the two vectors.
    [v1] is copied directly. *)

let append v1 v2 =
  let l1 = v1.length 
  and l2 = v2.length in
  let r = create (l1 + l2) false in
  let b1 = v1.bits in
  let b2 = v2.bits in
  let b = r.bits in
  for i = 0 to Array.length b1 - 1 do 
    Array.unsafe_set b i (Array.unsafe_get b1 i) 
  done;  
  unsafe_blit b2 0 b l1 l2;
  r

(*s The concatenation of a list of bit vectors is obtained by iterating
    [unsafe_blit]. *)

let concat vl =
  let size = List.fold_left (fun sz v -> sz + v.length) 0 vl in
  let res = create size false in
  let b = res.bits in
  let pos = ref 0 in
  List.iter
    (fun v ->
       let n = v.length in
       unsafe_blit v.bits 0 b !pos n;
       pos := !pos + n)
    vl;
  res

(*s Filling is a particular case of blitting with a source made of all
    ones or all zeros. Thus we instanciate [unsafe_blit], with 0 and
    [max_int]. *)

let blit_zeros v ofs len =
  let (bi,bj) = pos ofs in
  let (ei,ej) = pos (ofs + len - 1) in
  if bi == ei then
    blit_bits 0 bj len v ofs
  else begin
    blit_bits 0 bj (bpi - bj) v ofs;
    let n = ref (ofs + bpi - bj) in
    for i = succ bi to pred ei do
      blit_int 0 v !n;
      n := !n + bpi
    done;
    blit_bits 0 0 (succ ej) v !n
  end

let blit_ones v ofs len =
  let (bi,bj) = pos ofs in
  let (ei,ej) = pos (ofs + len - 1) in
  if bi == ei then
    blit_bits max_int bj len v ofs
  else begin
    blit_bits max_int bj (bpi - bj) v ofs;
    let n = ref (ofs + bpi - bj) in
    for i = succ bi to pred ei do
      blit_int max_int v !n;
      n := !n + bpi
    done;
    blit_bits max_int 0 (succ ej) v !n
  end

let fill v ofs len b =
  if ofs < 0 or len < 0 or ofs + len > v.length then invalid_arg "Bitv.fill";
  if b then blit_ones v.bits ofs len else blit_zeros v.bits ofs len

(*s All the iterators are implemented as for traditional arrays, using
    [unsafe_get]. For [iter] and [map], we do not precompute [(f
    true)] and [(f false)] since [f] is likely to have
    side-effects. *)

let iter f v =
  for i = 0 to v.length - 1 do f (unsafe_get v i) done

let map f v =
  let l = v.length in
  let r = create l false in
  for i = 0 to l - 1 do
    unsafe_set r i (f (unsafe_get v i))
  done;
  r

let iteri f v =
  for i = 0 to v.length - 1 do f i (unsafe_get v i) done

let mapi f v =
  let l = v.length in
  let r = create l false in
  for i = 0 to l - 1 do
    unsafe_set r i (f i (unsafe_get v i))
  done;
  r

let fold_right f x v =
  let r = ref x in
  for i = 0 to v.length - 1 do
    r := f !r (unsafe_get v i)
  done;
  !r

let fold_left f x v =
  let r = ref x in
  for i = v.length - 1 downto 0 do
    r := f !r (unsafe_get v i) 
  done;
  !r

(*s Bitwise operations. It is straigthforward, since bitwise operations
    can be realized by the corresponding bitwise operations over integers.
    However, one has to take care of normalizing the result of [bwnot]
    which introduces ones in highest significant positions. *)

exception All_zero

let intersect v1 v2 = 
  let l = v1.length in
  if l <> v2.length then invalid_arg "Bitv.intersect";
  let b1 = v1.bits 
  and b2 = v2.bits in
  let n = Array.length b1 in
  let a = Array.create n 0 in
  let all_zero = ref true in
  for i = 0 to n - 1 do
    a.(i) <- b1.(i) land b2.(i);
    if a.(i) > 0 then all_zero := false
  done;
  if !all_zero then raise All_zero;
  { length = l; bits = a; modif = true; level = 0 }

let bw_and v1 v2 = 
  let l = v1.length in
  if l <> v2.length then invalid_arg "Bitv.bw_and";
  let b1 = v1.bits 
  and b2 = v2.bits in
  let n = Array.length b1 in
  let a = Array.create n 0 in
  for i = 0 to n - 1 do
    a.(i) <- b1.(i) land b2.(i)
  done;
  { length = l; bits = a; modif = true; level = 0 }
  
let bw_or v1 v2 = 
  let l = v1.length in
  if l <> v2.length then invalid_arg "Bitv.bw_or";
  let b1 = v1.bits 
  and b2 = v2.bits in
  let n = Array.length b1 in
  let a = Array.create n 0 in
  for i = 0 to n - 1 do
    a.(i) <- b1.(i) lor b2.(i)
  done;
  { length = l; bits = a; modif = true; level = 0 }
  
let bw_xor v1 v2 = 
  let l = v1.length in
  if l <> v2.length then invalid_arg "Bitv.bw_xor";
  let b1 = v1.bits 
  and b2 = v2.bits in
  let n = Array.length b1 in
  let a = Array.create n 0 in
  for i = 0 to n - 1 do
    a.(i) <- b1.(i) lxor b2.(i)
  done;
  { length = l; bits = a; modif = true; level = 0 }
  
let bw_not v = 
  let b = v.bits in
  let n = Array.length b in
  let a = Array.create n 0 in
  for i = 0 to n - 1 do
    a.(i) <- max_int land (lnot b.(i))
  done;
  let r = { length = v.length; bits = a; modif = true; level = 0 } in
  normalize r;
  r

(*s Shift operations. It is easy to reuse [unsafe_blit], although it is 
    probably slightly less efficient than a ad-hoc piece of code. *)

let rec shiftl v d =
  if d == 0 then 
    copy v
  else if d < 0 then
    shiftr v (-d)
  else begin
    let n = v.length in
    let r = create n false in
    if d < n then unsafe_blit v.bits 0 r.bits d (n - d);
    r
  end
  
and shiftr v d =
  if d == 0 then 
    copy v
  else if d < 0 then
    shiftl v (-d)
  else begin
    let n = v.length in
    let r = create n false in
    if d < n then unsafe_blit v.bits d r.bits 0 (n - d);
    r
  end

(*s Testing for all zeros and all ones. *)

let all_zeros v = 
  let b = v.bits in
  let n = Array.length b in
  let rec test i = 
    (i == n) || ((Array.unsafe_get b i == 0) && test (succ i)) 
  in
  test 0

let all_ones v = 
  let b = v.bits in
  let n = Array.length b in
  let rec test i = 
    if i == n - 1 then
      let m = v.length mod bpi in
      (Array.unsafe_get b i) == (if m == 0 then max_int else low_mask.(m))
    else
      ((Array.unsafe_get b i) == max_int) && test (succ i)
  in
  test 0

(*s Conversions to and from strings. *)

let to_string v = 
  let n = v.length in
  let s = String.make n '0' in
  for i = 0 to n - 1 do
    if unsafe_get v i then s.[i] <- '1'
  done;
  s

let print fmt v = Format.pp_print_string fmt (to_string v)

let from_string s =
  let n = String.length s in
  let v = create n false in
  for i = 0 to n - 1 do
    let c = String.unsafe_get s i in
    if c = '1' then 
      unsafe_set v i true
    else 
      if c <> '0' then invalid_arg "Bitv.from_string"
  done;
  v

(*s Iteration on all bit vectors of length [n] using a Gray code. *)

let first_set v n = 
  let rec lookup i = 
    if i = n then raise Not_found ;
    if unsafe_get v i then i else lookup (i + 1)
  in 
  lookup 0

let gray_iter f n = 
  let bv = create n false in 
  let rec iter () =
    f bv; 
    unsafe_set bv 0 (not (unsafe_get bv 0));
    f bv; 
    let pos = succ (first_set bv n) in
    if pos < n then begin
      unsafe_set bv pos (not (unsafe_get bv pos));
      iter ()
    end
  in
  if n > 0 then iter ()


(*s Coercions to/from lists of intergers *)

let from_list l =
  let n = List.fold_left max 0 l in
  let b = create (succ n) false in
  let add_element i = 
    (* negative numbers are invalid *)
    if i < 0 then invalid_arg "Bitv.from_list";
    unsafe_set b i true 
  in
  List.iter add_element l;
  b

(*
let from_bool_ref_array a = 
  let n = Array.length a in
  let b = create n false in
  for i = 0 to n - 1 do if !(a.(i)) 
  then begin unsafe_set b i true; b.level <- b.level - 1 end done ;
  b.modif <- false;
  b
*)

let project_with_length l1 l2 len = 
  let b = create len false in
  let apply a x y = if !x then begin if !y then begin
    set b a true; end; pred a end else a in
  let _ = try List.fold_left2 (apply) (pred len) l1 l2
  with _ -> invalid_arg "project"
  in
  b
   

let from_list_with_length l len =
  let b = create len false in
  let add_element i =
    if i < 0 || i >= len then invalid_arg "Bitv.from_list_with_length";
    unsafe_set b i true
  in
  List.iter add_element l;
  b

let to_list b =
  let n = length b in
  let rec make i acc = 
    if i < 0 then acc 
    else make (pred i) (if unsafe_get b i then i :: acc else acc)
  in
  make (pred n) []

type ord = Unknown | Lower | Equal | Greater

let po_compare_with_bits v1 v2 = 
  let l1 = length v1 and l2 = length v2 in
  if l1 <> l2 then begin invalid_arg "Bitv.po_compare" end;
  let r = ref Equal in
  try 
    for i = 0 to l1 - 1 do 
      match !r, unsafe_get v1 i, unsafe_get v2 i with
      |  Equal , true , false  -> r := Lower
      |  Equal , false , true  -> r := Greater
      |  Lower , false , true  -> raise Exit
      |  Greater , true , false  -> raise Exit
      |  _ -> ()
    done; !r
  with Exit -> Unknown

let po_compare v1 v2 = 
  let l1 = length v1 and l2 = length v2 in
  if l1 <> l2 then begin invalid_arg "Bitv.po_compare" end;
  let b1 = v1.bits and b2 = v2.bits in
  let len = Array.length b1 in
  let r = ref Equal in
  try 
    for i = 0 to len - 1 do 
      let i1 = b1.(i) and i2 = b2.(i) in
      if i1 <> i2 then 
	let is = i1 land i2 in
	match !r, is with
	|  Equal , x -> 
	    if x = i2 
	    then r := Lower 
	    else if x = i1 
	    then r := Greater
	    else raise Exit
	|  Lower , x -> if x <> i2 then raise Exit
	|  Greater , x -> if x <> i1 then raise Exit
	|  _ -> ()
    done; !r
  with Exit -> Unknown

let le v1 v2 =
  let l1 = length v1 and l2 = length v2 in
  if l1 <> l2 then begin invalid_arg "Bitv.po_compare" end;
  let b1 = v1.bits and b2 = v2.bits in
  let len = Array.length b1 in
  let r = ref true in
  let i = ref 0 in
  while !i < len && !r 
  do let i1 = b1.(!i) and i2 = b2.(!i) in r := i1 land i2 = i2; incr i done;
  !r

let level v = 
  let c = ref v.length in
  if v.modif then begin 
    for i = 0 to v.length - 1 do if unsafe_get v i then decr c done;
    v.modif <- false; v.level <- !c; !c end
  else v.level

