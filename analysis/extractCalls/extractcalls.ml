(*
 * "Copyright (c) 2009 The Regents of the University  of California.
 * All rights reserved.
 *
 * Permission to use, copy, modify, and distribute this software and its
 * documentation for any purpose, without fee, and without written
 * agreement is hereby granted, provided that the above copyright
 * notice, the following two paragraphs and the author appear in all
 * copies of this software.
 *
 * IN NO EVENT SHALL THE UNIVERSITY OF CALIFORNIA BE LIABLE TO ANY PARTY
 * FOR DIRECT, INDIRECT, SPECIAL, INCIDENTAL, OR CONSEQUENTIAL DAMAGES
 * ARISING OUT OF THE USE OF THIS SOFTWARE AND ITS DOCUMENTATION, EVEN
 * IF THE UNIVERSITY OF CALIFORNIA HAS BEEN ADVISED OF THE POSSIBILITY
 * OF SUCH DAMAGE.
 *
 * THE UNIVERSITY OF CALIFORNIA SPECIFICALLY DISCLAIMS ANY WARRANTIES,
 * INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF
 * MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE.  THE SOFTWARE
 * PROVIDED HEREUNDER IS ON AN "AS IS" BASIS, AND THE UNIVERSITY OF
 * CALIFORNIA HAS NO OBLIGATION TO PROVIDE MAINTENANCE, SUPPORT,
 * UPDATES, ENHANCEMENTS, OR MODIFICATIONS."
 *
 * Author: Roy Shea (royshea@gmail.com)
 *)

open Cil
open Pretty

type functionCall = {name: string; inline: bool; funName: string};;


(* Append data to the list stored under key in hashTable.  If there is no entry
 * for key, then an entry is created. *)
let extendHashList hashTable key data =
  let storedData =
    try Hashtbl.find hashTable key
    with Not_found -> []
  in
    Hashtbl.replace hashTable key (data::storedData)
;;


(* Sort and uniqify a list. *)
let sortAndUniq l =

  let rec uniq l = match l with
      [] -> []
    | hd::[] -> [hd]
    | hd::next::rest ->
        if ((compare hd next) = 0) then uniq (hd::rest)
        else hd::(uniq (next::rest))
  in
    uniq (List.sort compare l)
;;


(* Visit a file and generate mapping of all called functions.  This requires
 * keeping track of the function that is currently being visited at any point in
 * time via the callingFunction value. *)
class callGraphClass functionHash = object
  inherit nopCilVisitor

  val mutable callingFunction = {name="__UNKNOWN__"; inline=false; funName="__UNKNOWN__"}

  method vfunc f =
    callingFunction <- {name=f.svar.vname; inline=f.svar.vinline; funName=f.svar.vdecl.file};
    extendHashList functionHash callingFunction "__DECLARATION__";
    DoChildren

  method vinst i = match i with
    | Call (_, Lval(Var vi, _), _, _) ->
        extendHashList functionHash callingFunction vi.vname;
        SkipChildren
    | Call (_, Lval(Mem _, _), _, _) ->
        extendHashList functionHash callingFunction "__FUNCTION_POINTER__";
        SkipChildren
    | Call _ ->
        assert false
    | _ -> SkipChildren

end


(* Wrap the class used to generate call graphs for a file. *)
let doFile functionHash fileName =

  let cilFile = Frontc.parse fileName () in

  (* Execute CIL modules *)
  let _ = Cfg.computeFileCFG cilFile in
  let _ = visitCilFile (new callGraphClass functionHash) cilFile in

    ()
;;


(* Load a machine model using the CIL_MACHINE enviornment variable. *)
let loadEnv _ =
  let _ =
    try
      let machineModel = Sys.getenv "CIL_MACHINE" in
        Cil.envMachine := Some (Machdepenv.modelParse machineModel);
    with
        Not_found ->
          ignore (Errormsg.error "CIL_MACHINE environment variable is not set")
      | Failure msg ->
          ignore (Errormsg.error "CIL_MACHINE machine model is invalid: %s" msg)
  in
    ()
;;


let mainFunction () =

  let functionHash = Hashtbl.create 100 in

  let usageMsg = "Usage: <program> [options] source-files" in
  let fileNames : string list ref = ref [] in

  let recordFile fname =
    fileNames := fname :: (!fileNames)
  in

  let argDescr = [
    ("--envmachine", Arg.Unit loadEnv, "Specify machine model using CIL_MACHINE environment variable");
  ] in

  let _ = Arg.parse argDescr recordFile usageMsg in

  let _ = Cil.initCIL () in
  let _ = List.iter (doFile functionHash) !fileNames in

    Hashtbl.iter
      (* Clean up the data in the hash table by removing duplicate call entries *)
      (fun key data -> Hashtbl.replace functionHash key (sortAndUniq data))
      functionHash;

    Hashtbl.iter
      (* Print edge data: isInlineCaller caller target *)
      (fun key data ->
         List.iter
           (fun target -> ignore (printf "%b %s %s %s\n" key.inline key.funName key.name target))
           data
      )
      functionHash;
;;


(* Do stuff *)
mainFunction ();;
