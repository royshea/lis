open Cil
open Pretty

(* Parse each line of of fileName using parseLine.  The parseLine function
 * should externally store any information of interest to the caller. *)
let readDataFile fileName parseLine =
  let ch = open_in fileName in

  let split = Str.split (Str.regexp_string " ") in

  let rec readLines () =
    match (try Some (split (input_line ch)) with _ -> None) with
      | None -> ()
      | Some line ->
          parseLine line;
          readLines ()
  in

    readLines ();
    close_in ch
;;


(* Insert a globalVar into a list of globals.  This attempts to insert globalVar
 * after globals from header files but before relevant C source code.  This is
 * accomplished by scanning through the globals and inserting the globalVar
 * directly before the first global found coming from a file without a dot h
 * extension. *)
let insertGlobalVar globalVar globals =

  let insertedVar = ref false in

  let insertAfterH globalList global =
    if not (Filename.check_suffix (get_globalLoc global).file ".h") &&
       not ((get_globalLoc global).file = "<compiler builtins>") &&
       not !insertedVar
    then (
      insertedVar := true;
      global :: GVarDecl (globalVar, locUnknown) :: globalList
    ) else (
      global :: globalList
    )
  in

  let revisedGlobals = List.rev (List.fold_left insertAfterH [] globals) in
  let _ = assert (!insertedVar) in

    revisedGlobals
;;


(* Return the var representing the logging function named logFunctionName.  This
 * searches for the function within cilFile and adds a declaration for
 * logFunctionName to cilFile if no declaration is found. *)
let getLogFunction logFunctionName cilFile =

  let logFunction = ref None in

  (* Scan file for logFunctionName *)
  iterGlobals cilFile (
    fun global -> match global with
      | GVarDecl (v, _) when v.vname = logFunctionName ->
          assert (!logFunction = None);
          logFunction := Some v
      | _ -> ()
  );

  (* If logFunctionName was found then return it.  Else create it, add it to the
   * list of globals, and return the created instance. *)
  match !logFunction with
      Some v -> v
    | None -> begin
        let v = makeGlobalVar logFunctionName
                  (TFun(voidType,
                        Some [("msg", charConstPtrType, [])],
                        false,
                        [])
                  )
        in
          v.vstorage <- Extern;
          cilFile.globals <- insertGlobalVar v cilFile.globals;
          v
      end
;;


(* Create a single instruction that calls the logging function logFun with
 * parameters v and width.  This function assumes logFun takes a single
 * string as its input. *)
let makeLogCallInstrWithVar logFun v width =
  let parameter =
    mkString (v.vname ^ " " ^ string_of_int width)
  in
    Call (None, Lval(var logFun), [parameter], !currentLoc)
;;


(* Create a single instruction that calls the logging function logFun with
 * parameters traceVal and width.  This function assumes logFun takes a single
 * string as its input. *)
let makeLogCallInstr logFun traceVal width =
  let parameter =
    mkString (string_of_int traceVal ^ " " ^ string_of_int width)
  in
    Call (None, Lval(var logFun), [parameter], !currentLoc)
;;


(* Create a statement containing a single instruction that calls the logging
 * function logFun with parameters traceVal and width.  This function assumes
 * logFun takes a single string as its input. *)
let makeLogCallStmt logFun traceVal width =
    mkStmtOneInstr (makeLogCallInstr logFun traceVal width)
;;


(* Upon entry to function f insert a call to logFun that records traceVal and
 * width. *)
let logOnEntry logFun traceVal width f =
  f.sbody.bstmts <- (makeLogCallStmt logFun traceVal width) :: f.sbody.bstmts
;;


(* Insert before instruction i a call to logFun that records traceVal and
 * width. *)
let logBeforeInstr logFun traceVal width i =
  [makeLogCallInstr logFun traceVal width; i]
;;


(* Insert stament newStmt immediately before statement oldStmt and presevering
 * the labels of oldStmt.  This is accomplished by creating a block to house the
 * body of the two statements and reusing the rest of oldStmt.  NOTE: May want
 * to update control flow graph after using this function.
 *)
let logBeforeStmt newStmt oldStmt =

  (* Hack to update line numbers used when pretty printing the resulting CIL file. *)
  let _ = (d_stmt () oldStmt) in

  let block = mkBlock (compactStmts [newStmt; mkStmt oldStmt.skind]) in
    oldStmt.skind <- Block block;
    oldStmt
;;


(* Helper class that uses hasVar to return true if any instance of vname is
 * found within the visited object *)
class includesVar vname hasVar = object inherit nopCilVisitor
  method vvrbl v =
    if v.vname = vname then hasVar := true;
    DoChildren
end


(* Checks to see if the current statement is a branch reached from an if,
 * switch, or loop of interest.  This is done by testing if any predecessor of
 * the statement is an If, Switch, or Loop and then filtering such statements
 * based on:
 * - Only return true for branches that are specified as being of interest
 *   within flags.  The flag values are:
 *   - If = 0x01
 *   - Switch = 0x02
 *   - Loop = 0x04
 *   - Combinations of flags are fine so 0x07 covers all types of branches.
 * - When some varNameOp is specified then only return true for branches that are
 *   guarded by an expression involving varName.
 *)
let isBranch s flags varNameOp =

  (* Return true if guard uses the name specified in varNameOp, or return true
   * if no name is specified in varNameOp. *)
  let varCheck guard = match varNameOp with
      None -> true
    | Some vname ->
        let hasVar = ref false in
          ignore (visitCilExpr (new includesVar vname hasVar) guard);
          !hasVar
  in

  (* Returns true if the numeric value of condition is set in flag.  Uses janky
   * local module syntax to embed the type information within isBranch. *)
  let module LisFlag = struct
    type condition = LisIf | LisSwitch | LisLoop;;
    let test flag c =
      match c with
          LisIf when flag land 0x01 > 0 -> true
        | LisSwitch when flag land 0x02 > 0 -> true
        | LisLoop when flag land 0x04 > 0 -> true
        | _ -> false
  end in

  List.exists
    (fun p -> match p.skind with
         If (guard, _, _, _) when LisFlag.test flags LisFlag.LisIf -> varCheck guard
       | Switch (guard, _, _, _) when LisFlag.test flags LisFlag.LisSwitch -> varCheck guard
       | Loop (_, _, _, _)  when LisFlag.test flags LisFlag.LisLoop -> true
       | If (guard, _, _, _) when LisFlag.test flags LisFlag.LisLoop ->
           (* This is a special case to handle how CIL transforms loops.  A
            * while(e) loop is rewritten as a while(1) {if (!e) break; ...}.
            * Because of this transformation we always track If guards when
            * LisLoop is specified AND a guard option is specified to watch. *)
           begin match varNameOp with
               Some vname -> varCheck guard
             | _ -> false
           end
       | _ -> false
    ) s.preds
;;


(* Insert a call to logFun using identifier id of width idWidth into the header
 * of host. *)
class insertHeader logFun host id idWidth = object
  inherit nopCilVisitor

  method vfunc f =
    if f.svar.vname = host then
      logOnEntry logFun id idWidth f;
    SkipChildren

end


(* Insert a call to logFun using identifier id of width idWidth into the footer
 * of host. *)
class insertFooter logFun host id idWidth  = object
  inherit nopCilVisitor

  val mutable currentFunc = dummyFunDec

  method vfunc f =
    currentFunc <- f;
    let updateCfg currentFunc =
      Cfg.clearCFGinfo currentFunc;
      ignore (Cfg.cfgFun currentFunc);
      currentFunc
    in
      if f.svar.vname = host then ChangeDoChildrenPost (f, updateCfg)
      else SkipChildren

  method vstmt s = match s.skind with
      Return (_, _) ->
        let logStmt = makeLogCallStmt logFun id idWidth in
          ChangeDoChildrenPost (s, (logBeforeStmt logStmt))
    | _ ->
        DoChildren

end


(* Insert a call to logFun using identifier id of width idWidth immediately
 * before any call to target within host. *)
class insertCalls logFun host target id idWidth = object
  inherit nopCilVisitor

  val mutable currentFun = ""

  method vfunc f =
    if f.svar.vname = host then DoChildren
    else SkipChildren

  method vinst i = match i with
    | Call(_, Lval(Var vi, _), _, _) when vi.vname = target ->
        ChangeTo (logBeforeInstr logFun id idWidth i)
    | Call(_, e, _, l) when "__PTR__" = target ->
        ChangeTo (logBeforeInstr logFun id idWidth i)
    | _ -> SkipChildren

end


(* Insert a call to logFun using identifier id of width idWidth immediately
 * after any instance where watchVar acts as the lval in a Set or Call
 * instruction. *)
class insertWatchpoints logFun host watchVar varWidth id idWidth = object
  inherit nopCilVisitor

  method vfunc f =
    if f.svar.vname = host then DoChildren
    else SkipChildren

  method vinst i = match i with
      Set ((Var v, _), _, _)
    | Call (Some (Var v, _), _, _, _) when v.vname = watchVar ->
        assert (varWidth = (bitsSizeOf v.vtype));
        ChangeTo [
          i;
          makeLogCallInstr logFun id idWidth;
          makeLogCallInstrWithVar logFun v (bitsSizeOf v.vtype);
        ]
    | _ -> SkipChildren;

end


(* Insert a call to logFun using an identifier from idList of width idWidth at
 * the top of each branch within host that is of interest as specified by flags
 * and vnameOp (see isBranch function for details).  Each branch is issued a
 * different ID from idList. *)
class insertConditionals logFun host flags vnameOp idList idWidth = object
  inherit nopCilVisitor

  val mutable branchStmts = []
  val mutable branchCounter = 0
  val mutable currentFunc = dummyFunDec

  method vfunc f =
    currentFunc <- f;

    let updateCfg currentFunc =
      Cfg.clearCFGinfo currentFunc;
      ignore (Cfg.cfgFun currentFunc);
      currentFunc
    in

      if f.svar.vname = host then ChangeDoChildrenPost (f, updateCfg)
      else SkipChildren


  method vstmt s =
      if (isBranch s flags vnameOp) && not (List.mem s.sid branchStmts) then (

        (* Create log statement and maintain branch counter. *)
        let nthId = List.nth idList branchCounter in
        let logStmt = makeLogCallStmt logFun nthId idWidth in
        let _ = branchStmts <- (s.sid :: branchStmts) in
        let _ = branchCounter <- 1 + branchCounter in
          ChangeDoChildrenPost (s, (logBeforeStmt logStmt))
      )
      else if (isBranch s flags vnameOp) then (
        failwith ("Safe to remove this \"else-if\". " ^
                  "Simply curious if this condition ever occurs.\n")
      )
      else DoChildren

end

