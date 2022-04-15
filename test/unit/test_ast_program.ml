open Ast_test_utils
open Lib
open Lib.Ast
open Alcotest
let program_testable =
  let program_pp ppf prog = Fmt.pf ppf "%s" (Ast_fmt.string_of_program prog) in
  let program_eq a b = (a = b) in
  testable program_pp program_eq

let test_multi_funcs () =
  (check program_testable) "same program"
  (parse_program "func main1(): none {} func main2(): none {}")
  ([],[
    {rtyp = NoneType; fname = "main1"; formals = []; locals = []; body = []};
    {rtyp = NoneType; fname = "main2"; formals = []; locals = []; body = []}]
  )

let test_multi_binds () = 
  (check program_testable) "same program"
  (parse_program "@@x: int; @@y: float;")
  ([(IntType, "x"); (FloatType, "y")],[])

let () = 
  run "Should able to parse program" [
    "multiple-functions", [
      test_case "Program with two functions" `Quick test_multi_funcs;
    ];
    "multiple-binds", [
      test_case "Program with binds only" `Quick test_multi_binds;
    ];
  ]