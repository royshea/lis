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
open Lowlog

(* Type describing LIS entries. *)
type lisScope = Global | Local | Point
and lisEntry =
    LHeader of string * lisScope
  | LFooter of string * lisScope
  | LCall of string * lisScope * string
  | LWatch of string * lisScope * string
  | LConditional of string * lisScope * int * string option
and rlisEntry =
    RHeader of string * lisScope * int * int
  | RFooter of string * lisScope * int * int
  | RCall of string * lisScope * string * int * int
  | RWatch of string * lisScope * string * int * int * int
  | RConditional of string * lisScope * int * string option * int * int * int
;;


(* Combine the scope and identifier into a single value to be logged and update
 * the width to reflect this change.  This is important to do such that a parser
 * can be easily implemented.  An easy solution for when each scope has a fixed
 * bitwidth is to use a unique prefix for each scope.  The parser can be written
 * to:
 * - Assume we are on a valid token
 *     - Read bits to determine scope
 *     - Use scope information to read bitwidth_of_scope bits
 *     - Back to a valid token so repeat
 * This version of scopeify accomplishes this using the following unique
 * binay prefixes:
 * - Point: None (the value of the ID is always 0)
 * - Global: 10
 * - Local: 11
 *)
let scopeify scope id width =

  let rec binStrOfInt i = match i with
      0 -> ""
    | _ -> (binStrOfInt (i lsr 1)) ^ (string_of_int (i land 1))
  in

  let sizedBinStrOfInt i len =
    let binStr = binStrOfInt i in
      try (String.make (len - String.length binStr) '0' ^ binStr)
      with Invalid_argument _ -> binStr
  in

    match scope with
        Point -> id, width
      | Global -> int_of_string ("0b" ^ "10" ^ (sizedBinStrOfInt id width)), width + 2
      | Local -> int_of_string ("0b" ^ "11" ^ (sizedBinStrOfInt id width)), width + 2
;;


(* Ranged version of scopeify (see comments for scopeify). *)
let scopeifyRange scope id width range =
  let rec rangedList i j = if i > j then [] else i :: (rangedList (i+1) j) in
  let ids = rangedList 0 (range - 1) in
  let scopeData = List.map (fun i -> scopeify scope i width) ids in
  let (scopeIds, scopeWidths) = List.split scopeData in
    if List.length scopeIds > 0 then
      (scopeIds, List.hd scopeWidths)
    else
      ([], 0)

;;


(* Parse a line from an LIS file.
 *
 * TODO: Add support for blank lines and comments via lines starting with a
 * pound symbol. *)
let readLis line =

  let stringToScope s = match s with
      "global" -> Global
    | "local" -> Local
    | "point" -> Point
    | _ -> failwith ("Invalid scope string: " ^ s)
  in

    match line with
      | ["header"; host; scope] ->
          LHeader (host, stringToScope scope)
      | ["footer"; host; scope] ->
          LFooter (host, stringToScope scope)
      | ["call"; host; scope; target] ->
          LCall (host, stringToScope scope, target)
      | ["watch"; host; scope; varName] ->
          LWatch (host, stringToScope scope, varName)
      | ["conditional"; host; scope; flags; varName] when varName = "__NULL__" ->
          if int_of_string flags = 0 then
            failwith ("LIS should specify non-zero value for conditional flags: " ^ flags);
          LConditional (host, stringToScope scope, (int_of_string flags), None)
      | ["conditional"; host; scope; flags; varName] ->
          if int_of_string flags = 0 then
            failwith ("LIS should specify non-zero value for conditional flags: " ^ flags);
          LConditional (host, stringToScope scope, (int_of_string flags), Some varName)
      | _ ->
          failwith (List.fold_left (fun full part -> full ^ " " ^ part)
                      "Invalied LIS entry: " line)
;;


(* Print RLIS entries. *)
let printRlis rlis channelOp =

  let outChannel = match channelOp with
      Some ch -> ch
    | None -> stdout
  in

  let scopeToString scope = match scope with
      Global -> "global"
    | Local -> "local"
    | Point -> "point"
  in

    List.iter
      (fun entry -> match entry with
           RHeader (host, scope, id, idWidth) ->
             ignore (Pretty.fprintf outChannel "header %s %s %d %d\n"
                       host (scopeToString scope) id idWidth);

         | RFooter (host, scope, id, idWidth) ->
             ignore (Pretty.fprintf outChannel "footer %s %s %d %d\n"
                       host (scopeToString scope) id idWidth);

         | RCall (host, scope, target, id, idWidth) ->
             ignore (Pretty.fprintf outChannel "call %s %s %s %d %d\n"
                       host (scopeToString scope) target id idWidth);

         | RWatch (host, scope, vname, varWidth, id, idWidth) ->
             ignore (Pretty.fprintf outChannel "watch %s %s %s %d %d %d\n"
                       host (scopeToString scope) vname varWidth id idWidth);

         | RConditional (host, scope, flags, Some vname, id, range, idWidth) ->
             ignore (Pretty.fprintf outChannel "conditional %s %s %d %s %d %d %d\n"
                       host (scopeToString scope) flags vname id range idWidth);

         | RConditional (host, scope, flags, None, id, range, idWidth) ->
             ignore (Pretty.fprintf outChannel "conditional %s %s %d %s %d %d %d\n"
                       host (scopeToString scope) flags "__NULL__" id range idWidth);
      ) rlis
;;


(* Use branchCount to return the number of branches associated with the LIS
 * entry of type LConditional within the function host. This function respects
 * the conditional types specified in flags and filters based on the value of
 * varNameOp. *)
class conditionCounter host flags varNameOp branchCount = object
  inherit nopCilVisitor

  (* branchStmts tracks the statements that will be logged.  This prevents
   * double counting statements. NOTE: Should check if this can ever occur or
   * if this is a needless complication. *)
  val mutable branchStmts = []

  method vfunc f =
    if f.svar.vname = host then DoChildren
    else SkipChildren

  method vstmt s =
      if (isBranch s flags varNameOp) && not (List.mem s.sid branchStmts) then (
        branchCount := 1 + !branchCount;
        branchStmts <- (s.sid :: branchStmts);
      );
      DoChildren

end


(* Return the bitsize of the variable named varName within the function named
 * host within varWidthOpt. *)
class findVarWidth host varName varWidth = object
  inherit nopCilVisitor

  method vfunc f =
    if f.svar.vname = host then DoChildren
    else SkipChildren

  method vinst i = match i with
      Set ((Var v, _), _, _)
    | Call (Some (Var v, _), _, _, _) when v.vname = varName ->
        varWidth := (bitsSizeOf v.vtype);
        SkipChildren
    | _ -> SkipChildren

end

(* Try to find the bit width of a variable *)
let getVarWidth host varName cilFile =
  let width = ref 0 in
  let vw = new findVarWidth host varName width in
    visitCilFileSameGlobals vw cilFile;
    !width
;;


(* Return a list of tuples recording the number of IDs that each LIS entry will
 * require.
 *
 * NOTE: Note that this does not look at overlapping requests from separate LIS
 * entries.  Not a bug with this function, but a minor optimization that may be
 * worth looking into later.
 *)
let getCounts lisData cilFile =
    List.map
      (fun entry -> match entry with
           LHeader _ | LFooter _  |  LCall _ | LWatch _ -> (entry, 1)
         | LConditional (host, _, flags, varNameOp) ->
             let branchCount = ref 0 in
             let cc = new conditionCounter host flags varNameOp branchCount in
             visitCilFileSameGlobals cc cilFile;
             (entry, !branchCount)
      ) lisData
;;


(* Filter lisData based on the requested scope. *)
let scopeFilterCounts lisCounts scope =
  List.filter
    (fun (entry, _) -> match entry with
         LHeader (_, s) | LFooter (_, s) | LCall (_, s, _) | LWatch (_, s, _)
         | LConditional (_, s, _, _) when s = scope -> true
         | _ -> false
    ) lisCounts
;;


(* Return the number of bits required to represent count distinct objects. *)
let getBitWidth count =
  if count = 0 then 0
  else if count = 1 then 1
  else int_of_float (ceil (log10 (float_of_int count) /. log10 2.))
;;


(* Convert global LIS entries to RLIS entries.  Note that the global entries use
 * a single shared name space for IDs. *)
let globalLisToRlis globalLis cilFile =

  let global_count = List.fold_left (fun sum (_, count) -> sum + count) 0 globalLis in
  let bitWidth = getBitWidth global_count in
  let currentId = ref 0 in

    List.map
      (fun (entry, count) -> match entry with
           LHeader (host, scope) ->
             assert (scope = Global);
             let entry = RHeader (host, scope, !currentId, bitWidth) in
               assert (count = 1);
               currentId := 1 + !currentId;
               entry

         | LFooter (host, scope) ->
             assert (scope = Global);
             let entry = RFooter (host, scope, !currentId, bitWidth) in
               assert (count = 1);
               currentId := 1 + !currentId;
               entry

         | LCall (host, scope, target) ->
             assert (scope = Global);
             let entry = RCall (host, scope, target, !currentId, bitWidth) in
               assert (count = 1);
               currentId := 1 + !currentId;
               entry

         | LWatch (host, scope, vname) ->
             assert (scope = Global);
             let varWidth = getVarWidth host vname cilFile in
             let entry = RWatch (host, scope, vname, varWidth, !currentId, bitWidth) in
               assert (count = 1);
               currentId := 1 + !currentId;
               entry

         | LConditional (host, scope, flags, vnameOp) ->
             assert (scope = Global);
             let entry = RConditional (host, scope, flags, vnameOp, !currentId, count, bitWidth) in
               currentId := count + !currentId;
               entry

      ) globalLis
;;


(* Convert local LIS entries to RLIS entries.  Note that local entries use
 * functionally scoped name spaces for IDs. *)
let localLisToRlis localLis cilFile =

  let getEntryHost entry = match entry with
      LHeader (host, _)
    | LFooter (host, _)
    | LCall (host, _, _)
    | LWatch (host, _, _)
    | LConditional (host, _, _, _) -> host
  in


  (* Build hash mapping function names to counts of IDs within that function. *)
  let countHash = Hashtbl.create 100 in
  let _ =
    List.iter
      (fun (entry, count) ->
         let host = getEntryHost entry in
         let current_count = try Hashtbl.find countHash host with Not_found -> 0 in
           Hashtbl.replace countHash host (current_count + count)
      )
      localLis
  in

  (* For each namespace calculate width needed to describe entries in and
   * initialize a counter tracking how many IDs have been used from the name
   * space.*)
  let widthHash = Hashtbl.create 100 in
  let _ =
    Hashtbl.iter
      (fun key value ->
         let idRef = ref 0 in
         Hashtbl.add widthHash key (idRef, (getBitWidth value))
      )
      countHash
  in

    List.map
      (fun (entry, count) -> match entry with
           LHeader (host, scope) ->
             assert (scope = Local);
             let (currentId, bitWidth) = Hashtbl.find widthHash host in
             let entry = RHeader (host, scope, !currentId, bitWidth) in
               assert (count = 1);
               currentId := 1 + !currentId;
               entry

         | LFooter (host, scope) ->
             assert (scope = Local);
             let (currentId, bitWidth) = Hashtbl.find widthHash host in
             let entry = RFooter (host, scope, !currentId, bitWidth) in
               assert (count = 1);
               currentId := 1 + !currentId;
               entry

         | LCall (host, scope, target) ->
             assert (scope = Local);
             let (currentId, bitWidth) = Hashtbl.find widthHash host in
             let entry = RCall (host, scope, target, !currentId, bitWidth) in
               assert (count = 1);
               currentId := 1 + !currentId;
               entry

         | LWatch (host, scope, vname) ->
             assert (scope = Local);
             let (currentId, bitWidth) = Hashtbl.find widthHash host in
             let varWidth = getVarWidth host vname cilFile in
             let entry = RWatch (host, scope, vname, varWidth, !currentId, bitWidth) in
               assert (count = 1);
               currentId := 1 + !currentId;
               entry

         | LConditional (host, scope, flags, vnameOp) ->
             assert (scope = Local);
             let (currentId, bitWidth) = Hashtbl.find widthHash host in
             let entry = RConditional (host, scope, flags, vnameOp, !currentId, count, bitWidth) in
               currentId := count + !currentId;
               entry

      ) localLis
;;


(* Convert point LIS entries to RLIS entries.  Note that the all point RLIS
 * entries use ID 0 and width 1. *)
let pointLisToRlis pointLis cilFile =

  List.map
    (fun (entry, count) -> match entry with
         LHeader (host, scope) ->
           assert (scope = Point);
           RHeader (host, scope, 0, 1)

       | LFooter (host, scope) ->
           assert (scope = Point);
           RFooter (host, scope, 0, 1)

       | LCall (host, scope, target) ->
           assert (scope = Point);
           RCall (host, scope, target, 0, 1)

       | LWatch (host, scope, vname) ->
           assert (scope = Point);
           let varWidth = getVarWidth host vname cilFile in
             RWatch (host, scope, vname, varWidth, 0, 1)

       | LConditional (host, scope, flags, vnameOp) ->
           assert (scope = Point);
           RConditional (host, scope, flags, vnameOp, 0, count, 1)

    ) pointLis
;;


(* Convert LIS into resolved LIS (RLIS) that includes set identifiers and scope
 * specific identifier widths.  Conversion from LIS to RLIS is a scope dependant
 * process that requires assinging each entry a scope specific ID and noting the
 * bitwidth required to encode IDs for the scope class. *)
let lisToRlis lisData cilFile =

  (* Generate count data for each lis entry, filter the entries into a single
   * scope, and generate rlis for that scope. *)
  let lisCounts = getCounts lisData cilFile in
  let rlisGlobals = globalLisToRlis (scopeFilterCounts lisCounts Global) cilFile in
  let rlisLocals = localLisToRlis (scopeFilterCounts lisCounts Local) cilFile in
  let rlisPoints = pointLisToRlis (scopeFilterCounts lisCounts Point) cilFile in

    rlisGlobals @ rlisLocals @ rlisPoints
;;


(* Apply a RLIS entry to cilFile *)
let applyREntry cilFile logFun entry =

  match entry with
      RHeader (host, scope, id, idWidth) ->
        let (scopeId, scopeIdWidth) = scopeify scope id idWidth in
          visitCilFileSameGlobals
            (new insertHeader logFun host scopeId scopeIdWidth)
            cilFile

    | RFooter (host, scope, id, idWidth) ->
        let (scopeId, scopeIdWidth) = scopeify scope id idWidth in
          visitCilFileSameGlobals
            (new insertFooter logFun host scopeId scopeIdWidth)
            cilFile

    | RCall (host, scope, target, id, idWidth) ->
        let (scopeId, scopeIdWidth) = scopeify scope id idWidth in
        visitCilFileSameGlobals
          (new insertCalls logFun host target scopeId scopeIdWidth)
          cilFile

    | RWatch (host, scope, vname, varWidth, id, idWidth) ->
        let (scopeId, scopeIdWidth) = scopeify scope id idWidth in
        visitCilFileSameGlobals
          (new insertWatchpoints logFun host vname varWidth scopeId scopeIdWidth)
          cilFile

    | RConditional (host, scope, flags, vnameOp, id, range, idWidth) ->
        let (scopeIdList, scopeIdWidth) = scopeifyRange scope id idWidth range in
        visitCilFileSameGlobals
          (new insertConditionals logFun host flags vnameOp scopeIdList scopeIdWidth)
          cilFile

;;


(* Instrumentation must be performed in a specific order to insure that specific
 * RLIS entry types occur at the correct flow within the program.  For example,
 * it is important that the LFooter logs always occur immediately before a return
 * and not have any logging messages trailing before the return.
 *
 * Correct order is:
 * - LConditional
 * - LWatch | LCall
 * - LFooter | LHeader
 *)
let sortRlis rlis =

  let conditionals =
    List.filter
      (fun rentry -> match rentry with
           RConditional _ ->  true
         | _ -> false)
      rlis
  in


  let watchesAndCalls =
    List.filter
      (fun rentry -> match rentry with
           RWatch _ | RCall  _ ->  true
         | _ -> false)
      rlis
  in

  let footersAndHeaders =
    List.filter
      (fun rentry -> match rentry with
           RFooter _ | RHeader  _ ->  true
         | _ -> false)
      rlis
  in

    conditionals @ watchesAndCalls @ footersAndHeaders
;;


(* Core driver function that manages conversion of LIS to RLIS and
 * instrumentation of the C program using the RLIS. *)
let applyLis lisData rlisChannel outChannel oneRet fileName =

  (* Basic setup to prepare for using LIS. *)
  let cilFile = Frontc.parse fileName () in
  let logFunctionName = "HOLDER_FUNC" in
  let logFun = getLogFunction logFunctionName cilFile in
  let _ = Cfg.computeFileCFG cilFile in
  let _ = if oneRet then Oneret.feature.fd_doit cilFile in

  (* Perform analysis needed to convert LIS to RLIS and then use RLIS to
   * instrument the code base.*)
  let rlis = lisToRlis lisData cilFile in
  let sortedRlis = sortRlis rlis in
  let _ = List.iter (applyREntry cilFile logFun) sortedRlis in

  (* Handle output of intermediate RLIS information and the C program augmented
   * with logging statements. *)
  let _ = printRlis sortedRlis rlisChannel in
  let _ = match outChannel with
      | None -> dumpFile !printerForMaincil stdout cilFile.fileName cilFile
      | Some c -> dumpFile !printerForMaincil c cilFile.fileName cilFile
  in

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


(* Entry point to LIS driven transformation.  Handles command line before
 * passing execution onto applyLis. *)
let mainFunction () =

  let usageMsg = "Usage: lis <options> source-file" in
  let fileNames : string list ref = ref [] in

  let recordFile fname =
    fileNames := fname :: (!fileNames)
  in

  let inLis = ref "" in
  let outRlisFile = ref "" in
  let outFile = ref "" in
  let oneRet = ref false in

  let argDescr = [
    ("--lis", Arg.Set_string inLis, "Name of LIS file");
    ("--rlis", Arg.Set_string outRlisFile, "Name file to write resolved LIS to");
    ("--out", Arg.Set_string outFile, "Name of the output CIL file");
    ("--oneret", Arg.Set oneRet, "Use CIL's one return transformation");
    ("--envmachine", Arg.Unit loadEnv, "Specify machine model using CIL_MACHINE environment variable");
  ] in

  let _ = Arg.parse argDescr recordFile usageMsg in

  let _ = if !inLis = "" then
    raise (Arg.Bad ("Must specify name of LIS file using --lis <lis_file>"))
  in

  let lisList = ref [] in

  let outRlisChannel =
    try Some (open_out !outRlisFile)
    with
        Sys_error _ when !outRlisFile = "" -> None
      | Sys_error _ -> raise (Arg.Bad ("Cannot open rlis output file " ^ !outRlisFile))
  in

  let outChannel =
    try Some (open_out !outFile)
    with
        Sys_error _ when !outFile = "" -> None
      | Sys_error _ -> raise (Arg.Bad ("Cannot open output file " ^ !outFile))
  in

    readDataFile !inLis (fun line -> lisList := (readLis line) :: !lisList);
    Cil.initCIL ();
    List.iter (applyLis !lisList outRlisChannel outChannel !oneRet) !fileNames;
;;


(* Do stuff *)
mainFunction ();;
