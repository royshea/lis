open Cil
open Pretty

type functionCall = {name: string; inline: bool; funName: string};;


let extendHashList hashTable key data =
  let storedData =
    try Hashtbl.find hashTable key
    with Not_found -> []
  in
    Hashtbl.replace hashTable key (data::storedData)
;;


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


let doFile functionHash fileName =

  let cilFile = Frontc.parse fileName () in

  (* Execute CIL modules *)
  let _ = Cfg.computeFileCFG cilFile in
  let _ = visitCilFile (new callGraphClass functionHash) cilFile in

    ()
;;


let mainFunction () =

  let functionHash = Hashtbl.create 100 in

  let usageMsg = "Usage: <program> [options] source-files" in
  let fileNames : string list ref = ref [] in

  let recordFile fname =
    fileNames := fname :: (!fileNames)
  in

  let _ = Arg.parse [] recordFile usageMsg in

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
