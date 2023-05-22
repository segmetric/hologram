defmodule Hologram.Compiler.TransformerTest do
  use Hologram.Test.BasicCase, async: true
  import Hologram.Compiler.Transformer

  alias Hologram.Compiler.Context
  alias Hologram.Compiler.IR

  describe "anonymous function call" do
    test "without args" do
      # test.()
      ast = {{:., [line: 1], [{:test, [line: 1], nil}]}, [line: 1], []}

      assert transform(ast, %Context{}) == %IR.AnonymousFunctionCall{
               function: %IR.Variable{name: :test},
               args: []
             }
    end

    test "with args" do
      # test.(1, 2)
      ast = {{:., [line: 1], [{:test, [line: 1], nil}]}, [line: 1], [1, 2]}

      assert transform(ast, %Context{}) == %IR.AnonymousFunctionCall{
               function: %IR.Variable{name: :test},
               args: [
                 %IR.IntegerType{value: 1},
                 %IR.IntegerType{value: 2}
               ]
             }
    end
  end

  describe "anonymous function type" do
    test "single clause, no params, single expression body" do
      # fn -> :expr_1 end
      ast = {:fn, [line: 1], [{:->, [line: 1], [[], {:__block__, [], [:expr_1]}]}]}

      assert transform(ast, %Context{}) == %IR.AnonymousFunctionType{
               arity: 0,
               clauses: [
                 %IR.AnonymousFunctionClause{
                   params: [],
                   body: %IR.Block{
                     expressions: [%IR.AtomType{value: :expr_1}]
                   }
                 }
               ]
             }
    end

    test "single param" do
      # fn x -> :expr_1 end
      ast =
        {:fn, [line: 1],
         [{:->, [line: 1], [[{:x, [line: 1], nil}], {:__block__, [], [:expr_1]}]}]}

      assert %IR.AnonymousFunctionType{
               arity: 1,
               clauses: [
                 %IR.AnonymousFunctionClause{
                   params: [%IR.Variable{name: :x}]
                 }
               ]
             } = transform(ast, %Context{})
    end

    test "multiple params" do
      # fn x, y -> :expr_1 end
      ast =
        {:fn, [line: 1],
         [
           {:->, [line: 1],
            [[{:x, [line: 1], nil}, {:y, [line: 1], nil}], {:__block__, [], [:expr_1]}]}
         ]}

      assert %IR.AnonymousFunctionType{
               arity: 2,
               clauses: [
                 %IR.AnonymousFunctionClause{
                   params: [
                     %IR.Variable{name: :x},
                     %IR.Variable{name: :y}
                   ]
                 }
               ]
             } = transform(ast, %Context{})
    end

    test "multiple expressions body" do
      # fn x ->
      #   :expr_1
      #   :expr_2
      # end
      ast =
        {:fn, [line: 1],
         [
           {:->, [line: 1], [[{:x, [line: 1], nil}], {:__block__, [], [:expr_1, :expr_2]}]}
         ]}

      assert %IR.AnonymousFunctionType{
               clauses: [
                 %IR.AnonymousFunctionClause{
                   body: %IR.Block{
                     expressions: [
                       %IR.AtomType{value: :expr_1},
                       %IR.AtomType{value: :expr_2}
                     ]
                   }
                 }
               ]
             } = transform(ast, %Context{})
    end

    test "multiple clauses" do
      # fn
      #   x ->
      #     :expr_1
      #   y ->
      #     :expr_2
      # end
      ast =
        {:fn, [line: 1],
         [
           {:->, [line: 2], [[{:x, [line: 2], nil}], {:__block__, [], [:expr_1]}]},
           {:->, [line: 4], [[{:y, [line: 4], nil}], {:__block__, [], [:expr_2]}]}
         ]}

      assert transform(ast, %Context{}) == %IR.AnonymousFunctionType{
               arity: 1,
               clauses: [
                 %IR.AnonymousFunctionClause{
                   params: [%IR.Variable{name: :x}],
                   body: %IR.Block{
                     expressions: [%IR.AtomType{value: :expr_1}]
                   }
                 },
                 %IR.AnonymousFunctionClause{
                   params: [%IR.Variable{name: :y}],
                   body: %IR.Block{
                     expressions: [%IR.AtomType{value: :expr_2}]
                   }
                 }
               ]
             }
    end
  end

  describe "atom type" do
    test "boolean" do
      # true
      ast = true

      assert transform(ast, %Context{}) == %IR.AtomType{value: true}
    end

    test "nil" do
      # nil
      ast = nil

      assert transform(ast, %Context{}) == %IR.AtomType{value: nil}
    end

    test "other than boolean or nil" do
      # :test
      ast = :test

      assert transform(ast, %Context{}) == %IR.AtomType{value: :test}
    end

    test "double quoted" do
      # :"aaa bbb"
      ast = :"aaa bbb"

      assert transform(ast, %Context{}) == %IR.AtomType{value: :"aaa bbb"}
    end
  end

  describe "bitstring type" do
    test "empty" do
      # <<>>
      ast = {:<<>>, [line: 1], []}

      assert transform(ast, %Context{}) == %IR.BitstringType{segments: []}
    end

    test "single segment" do
      # <<987>>
      ast = {:<<>>, [line: 1], [987]}

      assert %IR.BitstringType{segments: [%IR.BitstringSegment{}]} = transform(ast, %Context{})
    end

    test "multiple segments" do
      # <<987, 876>>
      ast = {:<<>>, [line: 1], [987, 876]}

      assert %IR.BitstringType{segments: [%IR.BitstringSegment{}, %IR.BitstringSegment{}]} =
               transform(ast, %Context{})
    end

    test "nested bistrings are flattened" do
      # <<333, <<444, 555, 666>>, 777>>
      ast = {:<<>>, [line: 1], [333, {:<<>>, [line: 1], [444, 555, 666]}, 777]}

      assert %IR.BitstringType{
               segments: [
                 %IR.BitstringSegment{value: %IR.IntegerType{value: 333}},
                 %IR.BitstringSegment{value: %IR.IntegerType{value: 444}},
                 %IR.BitstringSegment{value: %IR.IntegerType{value: 555}},
                 %IR.BitstringSegment{value: %IR.IntegerType{value: 666}},
                 %IR.BitstringSegment{value: %IR.IntegerType{value: 777}}
               ]
             } = transform(ast, %Context{})
    end

    # --- ENDIANNESS MODIFIER ---

    test "default endianness for binary type" do
      # <<xyz::binary>>
      ast =
        {:<<>>, [line: 1],
         [{:"::", [line: 1], [{:xyz, [line: 1], nil}, {:binary, [line: 1], nil}]}]}

      assert %IR.BitstringType{segments: [%IR.BitstringSegment{endianness: :not_applicable}]} =
               transform(ast, %Context{})
    end

    test "default endianness for bitstring type" do
      # <<xyz::bitstring>>
      ast =
        {:<<>>, [line: 1],
         [{:"::", [line: 1], [{:xyz, [line: 1], nil}, {:bitstring, [line: 1], nil}]}]}

      assert %IR.BitstringType{segments: [%IR.BitstringSegment{endianness: :not_applicable}]} =
               transform(ast, %Context{})
    end

    test "default endianness for float type" do
      # <<xyz::float>>
      ast =
        {:<<>>, [line: 1],
         [{:"::", [line: 1], [{:xyz, [line: 1], nil}, {:float, [line: 1], nil}]}]}

      assert %IR.BitstringType{segments: [%IR.BitstringSegment{endianness: :big}]} =
               transform(ast, %Context{})
    end

    test "default endianness for integer type" do
      # <<xyz::integer>>
      ast =
        {:<<>>, [line: 1],
         [{:"::", [line: 1], [{:xyz, [line: 1], nil}, {:integer, [line: 1], nil}]}]}

      assert %IR.BitstringType{segments: [%IR.BitstringSegment{endianness: :big}]} =
               transform(ast, %Context{})
    end

    test "default endianness for utf8 type" do
      # <<xyz::utf8>>
      ast =
        {:<<>>, [line: 1],
         [{:"::", [line: 1], [{:xyz, [line: 1], nil}, {:utf8, [line: 1], nil}]}]}

      assert %IR.BitstringType{segments: [%IR.BitstringSegment{endianness: :not_applicable}]} =
               transform(ast, %Context{})
    end

    test "default endianness for utf16 type" do
      # <<xyz::utf16>>
      ast =
        {:<<>>, [line: 1],
         [{:"::", [line: 1], [{:xyz, [line: 1], nil}, {:utf16, [line: 1], nil}]}]}

      assert %IR.BitstringType{segments: [%IR.BitstringSegment{endianness: :big}]} =
               transform(ast, %Context{})
    end

    test "default endianness for utf32 type" do
      # <<xyz::utf32>>
      ast =
        {:<<>>, [line: 1],
         [{:"::", [line: 1], [{:xyz, [line: 1], nil}, {:utf32, [line: 1], nil}]}]}

      assert %IR.BitstringType{segments: [%IR.BitstringSegment{endianness: :big}]} =
               transform(ast, %Context{})
    end

    test "big endianness modifier" do
      # <<xyz::big>>
      ast =
        {:<<>>, [line: 1], [{:"::", [line: 1], [{:xyz, [line: 1], nil}, {:big, [line: 1], nil}]}]}

      assert %IR.BitstringType{segments: [%IR.BitstringSegment{endianness: :big}]} =
               transform(ast, %Context{})
    end

    test "little endianness modifier" do
      # <<xyz::little>>
      ast =
        {:<<>>, [line: 1],
         [{:"::", [line: 1], [{:xyz, [line: 1], nil}, {:little, [line: 1], nil}]}]}

      assert %IR.BitstringType{segments: [%IR.BitstringSegment{endianness: :little}]} =
               transform(ast, %Context{})
    end

    test "native endianness modifier" do
      # <<xyz::native>>
      ast =
        {:<<>>, [line: 1],
         [{:"::", [line: 1], [{:xyz, [line: 1], nil}, {:native, [line: 1], nil}]}]}

      assert %IR.BitstringType{segments: [%IR.BitstringSegment{endianness: :native}]} =
               transform(ast, %Context{})
    end

    # --- SIGNEDNESS MODIFIER ---

    test "default signedness for binary type" do
      # <<xyz::binary>>
      ast =
        {:<<>>, [line: 1],
         [{:"::", [line: 1], [{:xyz, [line: 1], nil}, {:binary, [line: 1], nil}]}]}

      assert %IR.BitstringType{segments: [%IR.BitstringSegment{signedness: :not_applicable}]} =
               transform(ast, %Context{})
    end

    test "default signedness for bitstring type" do
      # <<xyz::bitstring>>
      ast =
        {:<<>>, [line: 1],
         [{:"::", [line: 1], [{:xyz, [line: 1], nil}, {:bitstring, [line: 1], nil}]}]}

      assert %IR.BitstringType{segments: [%IR.BitstringSegment{signedness: :not_applicable}]} =
               transform(ast, %Context{})
    end

    test "default signedness for float type" do
      # <<xyz::float>>
      ast =
        {:<<>>, [line: 1],
         [{:"::", [line: 1], [{:xyz, [line: 1], nil}, {:float, [line: 1], nil}]}]}

      assert %IR.BitstringType{segments: [%IR.BitstringSegment{signedness: :unsigned}]} =
               transform(ast, %Context{})
    end

    test "default signedness for integer type" do
      # <<xyz::integer>>
      ast =
        {:<<>>, [line: 1],
         [{:"::", [line: 1], [{:xyz, [line: 1], nil}, {:integer, [line: 1], nil}]}]}

      assert %IR.BitstringType{segments: [%IR.BitstringSegment{signedness: :unsigned}]} =
               transform(ast, %Context{})
    end

    test "default signedness for utf8 type" do
      # <<xyz::utf8>>
      ast =
        {:<<>>, [line: 1],
         [{:"::", [line: 1], [{:xyz, [line: 1], nil}, {:utf8, [line: 1], nil}]}]}

      assert %IR.BitstringType{segments: [%IR.BitstringSegment{signedness: :not_applicable}]} =
               transform(ast, %Context{})
    end

    test "default signedness for utf16 type" do
      # <<xyz::utf16>>
      ast =
        {:<<>>, [line: 1],
         [{:"::", [line: 1], [{:xyz, [line: 1], nil}, {:utf16, [line: 1], nil}]}]}

      assert %IR.BitstringType{segments: [%IR.BitstringSegment{signedness: :not_applicable}]} =
               transform(ast, %Context{})
    end

    test "default signedness for utf32 type" do
      # <<xyz::utf32>>
      ast =
        {:<<>>, [line: 1],
         [{:"::", [line: 1], [{:xyz, [line: 1], nil}, {:utf32, [line: 1], nil}]}]}

      assert %IR.BitstringType{segments: [%IR.BitstringSegment{signedness: :not_applicable}]} =
               transform(ast, %Context{})
    end

    test "signed signedness modifier" do
      # <<xyz::signed>>
      ast =
        {:<<>>, [line: 1],
         [{:"::", [line: 1], [{:xyz, [line: 1], nil}, {:signed, [line: 1], nil}]}]}

      assert %IR.BitstringType{segments: [%IR.BitstringSegment{signedness: :signed}]} =
               transform(ast, %Context{})
    end

    test "unsigned signedness modifier" do
      # <<xyz::unsigned>>
      ast =
        {:<<>>, [line: 1],
         [{:"::", [line: 1], [{:xyz, [line: 1], nil}, {:unsigned, [line: 1], nil}]}]}

      assert %IR.BitstringType{segments: [%IR.BitstringSegment{signedness: :unsigned}]} =
               transform(ast, %Context{})
    end

    # --- SIZE MODIFIER ---

    test "default size for float type" do
      # <<xyz::float>>
      ast =
        {:<<>>, [line: 1],
         [{:"::", [line: 1], [{:xyz, [line: 1], nil}, {:float, [line: 1], nil}]}]}

      assert %IR.BitstringType{segments: [%IR.BitstringSegment{size: %IR.IntegerType{value: 64}}]} =
               transform(ast, %Context{})
    end

    test "default size for integer type" do
      # <<xyz::integer>>
      ast =
        {:<<>>, [line: 1],
         [{:"::", [line: 1], [{:xyz, [line: 1], nil}, {:integer, [line: 1], nil}]}]}

      assert %IR.BitstringType{segments: [%IR.BitstringSegment{size: %IR.IntegerType{value: 8}}]} =
               transform(ast, %Context{})
    end

    test "default size for string values" do
      # <<"foo">>
      ast = {:<<>>, [line: 1], ["foo"]}

      assert %IR.BitstringType{segments: [%IR.BitstringSegment{size: %IR.IntegerType{value: 3}}]} =
               transform(ast, %Context{})
    end

    test "unknown size" do
      # <<xyz::binary>>
      ast =
        {:<<>>, [line: 1],
         [{:"::", [line: 1], [{:xyz, [line: 1], nil}, {:binary, [line: 1], nil}]}]}

      assert %IR.BitstringType{segments: [%IR.BitstringSegment{size: %IR.AtomType{value: nil}}]} =
               transform(ast, %Context{})
    end

    test "explicit size modifier syntax" do
      # <<xyz::size(3)>>
      ast =
        {:<<>>, [line: 1],
         [{:"::", [line: 1], [{:xyz, [line: 1], nil}, {:size, [line: 1], [3]}]}]}

      assert %IR.BitstringType{segments: [%IR.BitstringSegment{size: %IR.IntegerType{value: 3}}]} =
               transform(ast, %Context{})
    end

    test "shorthand size modifier syntax" do
      # <<xyz::3>>
      ast = {:<<>>, [line: 1], [{:"::", [line: 1], [{:xyz, [line: 1], nil}, 3]}]}

      assert %IR.BitstringType{segments: [%IR.BitstringSegment{size: %IR.IntegerType{value: 3}}]} =
               transform(ast, %Context{})
    end

    test "shorthand size modifier syntax inside size * unit group" do
      # <<xyz::3*5>>
      ast =
        {:<<>>, [line: 1],
         [{:"::", [line: 1], [{:xyz, [line: 1], nil}, {:*, [line: 1], [3, 5]}]}]}

      assert %IR.BitstringType{segments: [%IR.BitstringSegment{size: %IR.IntegerType{value: 3}}]} =
               transform(ast, %Context{})
    end

    # --- TYPE MODIFIER ---

    test "default type for variable value" do
      # <<xyz>>
      ast = {:<<>>, [line: 1], [{:xyz, [line: 1], nil}]}

      assert %IR.BitstringType{segments: [%IR.BitstringSegment{type: :integer}]} =
               transform(ast, %Context{})
    end

    test "default type for float data type" do
      # <<5.0>>
      ast = {:<<>>, [line: 1], [5.0]}

      assert %IR.BitstringType{segments: [%IR.BitstringSegment{type: :float}]} =
               transform(ast, %Context{})
    end

    test "default type for integer data type" do
      # <<5>>
      ast = {:<<>>, [line: 1], [5]}

      assert %IR.BitstringType{segments: [%IR.BitstringSegment{type: :integer}]} =
               transform(ast, %Context{})
    end

    test "default type for string data type" do
      # <<"abc">>
      ast = {:<<>>, [line: 1], ["abc"]}

      assert %IR.BitstringType{segments: [%IR.BitstringSegment{type: :utf8}]} =
               transform(ast, %Context{})
    end

    test "binary type modifier" do
      # <<xyz::binary>>
      ast =
        {:<<>>, [line: 1],
         [{:"::", [line: 1], [{:xyz, [line: 1], nil}, {:binary, [line: 1], nil}]}]}

      assert %IR.BitstringType{segments: [%IR.BitstringSegment{type: :binary}]} =
               transform(ast, %Context{})
    end

    test "bits type modifier" do
      # <<xyz::bits>>
      ast =
        {:<<>>, [line: 1],
         [{:"::", [line: 1], [{:xyz, [line: 1], nil}, {:bits, [line: 1], nil}]}]}

      assert %IR.BitstringType{segments: [%IR.BitstringSegment{type: :bitstring}]} =
               transform(ast, %Context{})
    end

    test "bitstring type modifier" do
      # <<xyz::bitstring>>
      ast =
        {:<<>>, [line: 1],
         [{:"::", [line: 1], [{:xyz, [line: 1], nil}, {:bitstring, [line: 1], nil}]}]}

      assert %IR.BitstringType{segments: [%IR.BitstringSegment{type: :bitstring}]} =
               transform(ast, %Context{})
    end

    test "bytes type modifier" do
      # <<xyz::bytes>>
      ast =
        {:<<>>, [line: 1],
         [{:"::", [line: 1], [{:xyz, [line: 1], nil}, {:bytes, [line: 1], nil}]}]}

      assert %IR.BitstringType{segments: [%IR.BitstringSegment{type: :binary}]} =
               transform(ast, %Context{})
    end

    test "float type modifier" do
      # <<xyz::float>>
      ast =
        {:<<>>, [line: 1],
         [{:"::", [line: 1], [{:xyz, [line: 1], nil}, {:float, [line: 1], nil}]}]}

      assert %IR.BitstringType{segments: [%IR.BitstringSegment{type: :float}]} =
               transform(ast, %Context{})
    end

    test "integer type modifier" do
      # <<xyz::integer>>
      ast =
        {:<<>>, [line: 1],
         [{:"::", [line: 1], [{:xyz, [line: 1], nil}, {:integer, [line: 1], nil}]}]}

      assert %IR.BitstringType{segments: [%IR.BitstringSegment{type: :integer}]} =
               transform(ast, %Context{})
    end

    test "utf8 type modifier" do
      # <<xyz::utf8>>
      ast =
        {:<<>>, [line: 1],
         [{:"::", [line: 1], [{:xyz, [line: 1], nil}, {:utf8, [line: 1], nil}]}]}

      assert %IR.BitstringType{segments: [%IR.BitstringSegment{type: :utf8}]} =
               transform(ast, %Context{})
    end

    test "utf16 type modifier" do
      # <<xyz::utf16>>
      ast =
        {:<<>>, [line: 1],
         [{:"::", [line: 1], [{:xyz, [line: 1], nil}, {:utf16, [line: 1], nil}]}]}

      assert %IR.BitstringType{segments: [%IR.BitstringSegment{type: :utf16}]} =
               transform(ast, %Context{})
    end

    test "utf32 type modifier" do
      # <<xyz::utf32>>
      ast =
        {:<<>>, [line: 1],
         [{:"::", [line: 1], [{:xyz, [line: 1], nil}, {:utf32, [line: 1], nil}]}]}

      assert %IR.BitstringType{segments: [%IR.BitstringSegment{type: :utf32}]} =
               transform(ast, %Context{})
    end

    # --- UNIT MODIFIER ---

    test "default unit for binary type" do
      # <<xyz::binary>>
      ast =
        {:<<>>, [line: 1],
         [{:"::", [line: 1], [{:xyz, [line: 1], nil}, {:binary, [line: 1], nil}]}]}

      assert %IR.BitstringType{segments: [%IR.BitstringSegment{unit: 8}]} =
               transform(ast, %Context{})
    end

    test "default unit for bistring type" do
      # <<xyz::bitstring>>
      ast =
        {:<<>>, [line: 1],
         [{:"::", [line: 1], [{:xyz, [line: 1], nil}, {:bitstring, [line: 1], nil}]}]}

      assert %IR.BitstringType{segments: [%IR.BitstringSegment{unit: nil}]} =
               transform(ast, %Context{})
    end

    test "default unit for float type" do
      # <<xyz::float>>
      ast =
        {:<<>>, [line: 1],
         [{:"::", [line: 1], [{:xyz, [line: 1], nil}, {:float, [line: 1], nil}]}]}

      assert %IR.BitstringType{segments: [%IR.BitstringSegment{unit: 1}]} =
               transform(ast, %Context{})
    end

    test "default unit for integer type" do
      # <<xyz::integer>>
      ast =
        {:<<>>, [line: 1],
         [{:"::", [line: 1], [{:xyz, [line: 1], nil}, {:integer, [line: 1], nil}]}]}

      assert %IR.BitstringType{segments: [%IR.BitstringSegment{unit: 1}]} =
               transform(ast, %Context{})
    end

    test "default unit for utf8 type" do
      # <<xyz::utf8>>
      ast =
        {:<<>>, [line: 1],
         [{:"::", [line: 1], [{:xyz, [line: 1], nil}, {:utf8, [line: 1], nil}]}]}

      assert %IR.BitstringType{segments: [%IR.BitstringSegment{unit: 8}]} =
               transform(ast, %Context{})
    end

    test "default unit for utf16 type" do
      # <<xyz::utf16>>
      ast =
        {:<<>>, [line: 1],
         [{:"::", [line: 1], [{:xyz, [line: 1], nil}, {:utf16, [line: 1], nil}]}]}

      assert %IR.BitstringType{segments: [%IR.BitstringSegment{unit: 16}]} =
               transform(ast, %Context{})
    end

    test "default unit for utf32 type" do
      # <<xyz::utf32>>
      ast =
        {:<<>>, [line: 1],
         [{:"::", [line: 1], [{:xyz, [line: 1], nil}, {:utf32, [line: 1], nil}]}]}

      assert %IR.BitstringType{segments: [%IR.BitstringSegment{unit: 32}]} =
               transform(ast, %Context{})
    end

    test "explicit unit modifier syntax" do
      # <<xyz::unit(3)>>
      ast =
        {:<<>>, [line: 1],
         [{:"::", [line: 1], [{:xyz, [line: 1], nil}, {:unit, [line: 1], [3]}]}]}

      assert %IR.BitstringType{segments: [%IR.BitstringSegment{unit: 3}]} =
               transform(ast, %Context{})
    end

    test "shorthand unit modifier syntax inside size * unit group" do
      # <<xyz::3*5>>
      ast =
        {:<<>>, [line: 1],
         [{:"::", [line: 1], [{:xyz, [line: 1], nil}, {:*, [line: 1], [3, 5]}]}]}

      assert %IR.BitstringType{segments: [%IR.BitstringSegment{unit: 5}]} =
               transform(ast, %Context{})
    end

    # --- VALUE ---

    test "integer value" do
      # <<6>>
      ast = {:<<>>, [line: 1], [6]}

      assert %IR.BitstringType{segments: [%IR.BitstringSegment{value: %IR.IntegerType{value: 6}}]} =
               transform(ast, %Context{})
    end

    test "string value" do
      # <<"my_str">>
      ast = {:<<>>, [line: 1], ["my_str"]}

      %IR.BitstringType{segments: [%IR.BitstringSegment{value: %IR.StringType{value: "my_str"}}]} =
        transform(ast, %Context{})
    end

    test "variable value" do
      # <<xyz>>
      ast = {:<<>>, [line: 1], [{:xyz, [line: 1], nil}]}

      assert %IR.BitstringType{segments: [%IR.BitstringSegment{value: %IR.Variable{name: :xyz}}]} =
               transform(ast, %Context{})
    end

    test "expression value" do
      # <<Map.get(my_map, :my_key)>>
      ast =
        {:<<>>, [line: 1],
         [
           {{:., [line: 1], [{:__aliases__, [line: 1], [:Map]}, :get]}, [line: 1],
            [{:my_map, [line: 1], nil}, :my_key]}
         ]}

      %IR.BitstringType{
        segments: [
          %IR.BitstringSegment{
            value: %IR.RemoteFunctionCall{
              module: %IR.AtomType{value: Map},
              function: :get,
              args: [%IR.Variable{name: :my_map}, %IR.AtomType{value: :my_key}]
            }
          }
        ]
      } = transform(ast, %Context{})
    end
  end

  test "block" do
    #  1
    #  2
    ast = {:__block__, [], [1, 2]}

    assert transform(ast, %Context{}) == %IR.Block{
             expressions: [
               %IR.IntegerType{value: 1},
               %IR.IntegerType{value: 2}
             ]
           }
  end

  describe "capture operator" do
    test "local function capture" do
      # &my_fun/2
      ast = {:&, [line: 1], [{:/, [line: 1], [{:my_fun, [line: 1], nil}, 2]}]}

      assert transform(ast, %Context{}) == %IR.AnonymousFunctionType{
               arity: 2,
               clauses: [
                 %IR.AnonymousFunctionClause{
                   params: [
                     %IR.Variable{name: :holo_arg_1__},
                     %IR.Variable{name: :holo_arg_2__}
                   ],
                   body: %IR.Block{
                     expressions: [
                       %IR.LocalFunctionCall{
                         function: :my_fun,
                         args: [
                           %IR.Variable{name: :holo_arg_1__},
                           %IR.Variable{name: :holo_arg_2__}
                         ]
                       }
                     ]
                   }
                 }
               ]
             }
    end

    test "remote function capture" do
      # &Calendar.ISO.parse_date/2
      ast =
        {:&, [line: 1],
         [
           {:/, [line: 1],
            [
              {{:., [line: 1], [{:__aliases__, [line: 1], [:Calendar, :ISO]}, :parse_date]},
               [no_parens: true, line: 1], []},
              2
            ]}
         ]}

      assert transform(ast, %Context{}) == %IR.AnonymousFunctionType{
               arity: 2,
               clauses: [
                 %IR.AnonymousFunctionClause{
                   params: [
                     %IR.Variable{name: :holo_arg_1__},
                     %IR.Variable{name: :holo_arg_2__}
                   ],
                   body: %IR.Block{
                     expressions: [
                       %IR.RemoteFunctionCall{
                         module: %IR.AtomType{value: Calendar.ISO},
                         function: :parse_date,
                         args: [
                           %IR.Variable{name: :holo_arg_1__},
                           %IR.Variable{name: :holo_arg_2__}
                         ]
                       }
                     ]
                   }
                 }
               ]
             }
    end

    test "partially applied local function" do
      # &my_fun(&1, 2, [3, &4])
      ast =
        {:&, [line: 1],
         [{:my_fun, [line: 1], [{:&, [line: 1], [1]}, 2, [3, {:&, [line: 1], [4]}]]}]}

      assert transform(ast, %Context{}) == %IR.AnonymousFunctionType{
               arity: 4,
               clauses: [
                 %IR.AnonymousFunctionClause{
                   params: [
                     %IR.Variable{name: :holo_arg_1__},
                     %IR.Variable{name: :holo_arg_2__},
                     %IR.Variable{name: :holo_arg_3__},
                     %IR.Variable{name: :holo_arg_4__}
                   ],
                   body: %IR.Block{
                     expressions: [
                       %IR.LocalFunctionCall{
                         function: :my_fun,
                         args: [
                           %IR.Variable{name: :holo_arg_1__},
                           %IR.IntegerType{value: 2},
                           %IR.ListType{
                             data: [
                               %IR.IntegerType{value: 3},
                               %IR.Variable{name: :holo_arg_4__}
                             ]
                           }
                         ]
                       }
                     ]
                   }
                 }
               ]
             }
    end

    test "partially applied remote function" do
      # &Aaa.Bbb.my_fun(&1, 2, [3, &4])
      ast =
        {:&, [line: 1],
         [
           {{:., [line: 1], [{:__aliases__, [line: 1], [:Aaa, :Bbb]}, :my_fun]}, [line: 1],
            [{:&, [line: 1], [1]}, 2, [3, {:&, [line: 1], [4]}]]}
         ]}

      assert transform(ast, %Context{}) == %IR.AnonymousFunctionType{
               arity: 4,
               clauses: [
                 %IR.AnonymousFunctionClause{
                   params: [
                     %IR.Variable{name: :holo_arg_1__},
                     %IR.Variable{name: :holo_arg_2__},
                     %IR.Variable{name: :holo_arg_3__},
                     %IR.Variable{name: :holo_arg_4__}
                   ],
                   body: %IR.Block{
                     expressions: [
                       %IR.RemoteFunctionCall{
                         module: %IR.AtomType{value: Aaa.Bbb},
                         function: :my_fun,
                         args: [
                           %IR.Variable{name: :holo_arg_1__},
                           %IR.IntegerType{value: 2},
                           %IR.ListType{
                             data: [
                               %IR.IntegerType{value: 3},
                               %IR.Variable{name: :holo_arg_4__}
                             ]
                           }
                         ]
                       }
                     ]
                   }
                 }
               ]
             }
    end

    test "partially applied anonymous function" do
      # &([&1, 2, my_fun(&3)])
      ast =
        {:&, [line: 1], [[{:&, [line: 1], [1]}, 2, {:my_fun, [line: 1], [{:&, [line: 1], [3]}]}]]}

      assert transform(ast, %Context{}) == %IR.AnonymousFunctionType{
               arity: 3,
               clauses: [
                 %IR.AnonymousFunctionClause{
                   params: [
                     %IR.Variable{name: :holo_arg_1__},
                     %IR.Variable{name: :holo_arg_2__},
                     %IR.Variable{name: :holo_arg_3__}
                   ],
                   body: %IR.Block{
                     expressions: [
                       %IR.ListType{
                         data: [
                           %IR.Variable{name: :holo_arg_1__},
                           %IR.IntegerType{value: 2},
                           %IR.LocalFunctionCall{
                             function: :my_fun,
                             args: [%IR.Variable{name: :holo_arg_3__}]
                           }
                         ]
                       }
                     ]
                   }
                 }
               ]
             }
    end
  end

  describe "case expression" do
    test "single clause without guard, single expression body" do
      # case x do
      #   1 -> :expr_1
      # end
      ast =
        {:case, [line: 2],
         [
           {:x, [line: 2], nil},
           [do: [{:->, [line: 3], [[1], {:__block__, [], [:expr_1]}]}]]
         ]}

      assert transform(ast, %Context{}) == %IR.CaseExpression{
               condition: %IR.Variable{name: :x},
               clauses: [
                 %IR.CaseClause{
                   head: %IR.IntegerType{value: 1},
                   body: %IR.Block{
                     expressions: [%IR.AtomType{value: :expr_1}]
                   }
                 }
               ]
             }
    end

    test "multiple clauses" do
      # case x do
      #   1 -> :expr_1
      #   2 -> :expr_2
      # end
      ast =
        {:case, [line: 2],
         [
           {:x, [line: 2], nil},
           [
             do: [
               {:->, [line: 3], [[1], {:__block__, [], [:expr_1]}]},
               {:->, [line: 4], [[2], {:__block__, [], [:expr_2]}]}
             ]
           ]
         ]}

      assert transform(ast, %Context{}) == %IR.CaseExpression{
               condition: %IR.Variable{name: :x},
               clauses: [
                 %IR.CaseClause{
                   head: %IR.IntegerType{value: 1},
                   body: %IR.Block{
                     expressions: [%IR.AtomType{value: :expr_1}]
                   }
                 },
                 %IR.CaseClause{
                   head: %IR.IntegerType{value: 2},
                   body: %IR.Block{
                     expressions: [%IR.AtomType{value: :expr_2}]
                   }
                 }
               ]
             }
    end

    test "multiple expressions body" do
      # case x do
      #   1 ->
      #     :expr_1
      #     :expr_2
      # end
      ast =
        {:case, [line: 2],
         [
           {:x, [line: 2], nil},
           [do: [{:->, [line: 3], [[1], {:__block__, [], [:expr_1, :expr_2]}]}]]
         ]}

      assert transform(ast, %Context{}) == %IR.CaseExpression{
               condition: %IR.Variable{name: :x},
               clauses: [
                 %IR.CaseClause{
                   head: %IR.IntegerType{value: 1},
                   body: %IR.Block{
                     expressions: [
                       %IR.AtomType{value: :expr_1},
                       %IR.AtomType{value: :expr_2}
                     ]
                   }
                 }
               ]
             }
    end

    test "guard" do
      # case x do
      #   {:ok, n} when is_integer(n) -> :expr_1
      # end
      ast =
        {:case, [line: 1],
         [
           {:x, [line: 1], nil},
           [
             do: [
               {:->, [line: 2],
                [
                  [
                    {:when, [line: 2],
                     [
                       {:ok, {:n, [line: 2], nil}},
                       {:is_integer, [line: 2], [{:n, [line: 2], nil}]}
                     ]}
                  ],
                  {:__block__, [], [:expr_1]}
                ]}
             ]
           ]
         ]}

      assert transform(ast, %Context{}) == %IR.CaseExpression{
               condition: %IR.Variable{name: :x},
               clauses: [
                 %IR.CaseClause{
                   head: %IR.TupleType{
                     data: [
                       %IR.AtomType{value: :ok},
                       %IR.Variable{name: :n}
                     ]
                   },
                   guard: %IR.LocalFunctionCall{
                     function: :is_integer,
                     args: [%IR.Variable{name: :n}]
                   },
                   body: %IR.Block{
                     expressions: [%IR.AtomType{value: :expr_1}]
                   }
                 }
               ]
             }
    end
  end

  describe "cond expression" do
    test "single clause, single expression body" do
      # cond do
      #   1 -> :expr_1
      # end
      ast = {:cond, [line: 2], [[do: [{:->, [line: 3], [[1], {:__block__, [], [:expr_1]}]}]]]}

      assert transform(ast, %Context{}) == %IR.CondExpression{
               clauses: [
                 %IR.CondClause{
                   condition: %IR.IntegerType{value: 1},
                   body: %IR.Block{
                     expressions: [%IR.AtomType{value: :expr_1}]
                   }
                 }
               ]
             }
    end

    test "multiple clauses" do
      # cond do
      #   1 -> :expr_1
      #   2 -> :expr_2
      # end
      ast =
        {:cond, [line: 2],
         [
           [
             do: [
               {:->, [line: 3], [[1], {:__block__, [], [:expr_1]}]},
               {:->, [line: 4], [[2], {:__block__, [], [:expr_2]}]}
             ]
           ]
         ]}

      assert transform(ast, %Context{}) == %IR.CondExpression{
               clauses: [
                 %IR.CondClause{
                   condition: %IR.IntegerType{value: 1},
                   body: %IR.Block{
                     expressions: [%IR.AtomType{value: :expr_1}]
                   }
                 },
                 %IR.CondClause{
                   condition: %IR.IntegerType{value: 2},
                   body: %IR.Block{
                     expressions: [%IR.AtomType{value: :expr_2}]
                   }
                 }
               ]
             }
    end

    test "multiple expressions body" do
      # cond do
      #   1 ->
      #     :expr_1
      #     :expr_2
      # end
      ast =
        {:cond, [line: 2],
         [[do: [{:->, [line: 3], [[1], {:__block__, [], [:expr_1, :expr_2]}]}]]]}

      assert transform(ast, %Context{}) == %IR.CondExpression{
               clauses: [
                 %IR.CondClause{
                   condition: %IR.IntegerType{value: 1},
                   body: %IR.Block{
                     expressions: [
                       %IR.AtomType{value: :expr_1},
                       %IR.AtomType{value: :expr_2}
                     ]
                   }
                 }
               ]
             }
    end
  end

  test "cons operator" do
    # [h | t]
    ast = [{:|, [line: 1], [{:h, [line: 1], nil}, {:t, [line: 1], nil}]}]

    assert transform(ast, %Context{}) == %IR.ConsOperator{
             head: %IR.Variable{name: :h},
             tail: %IR.Variable{name: :t}
           }
  end

  test "dot operator" do
    # abc.x
    ast = {{:., [line: 1], [{:abc, [line: 1], nil}, :x]}, [no_parens: true, line: 1], []}

    assert transform(ast, %Context{}) == %IR.DotOperator{
             left: %IR.Variable{name: :abc},
             right: %IR.AtomType{value: :x}
           }
  end

  test "float type" do
    # 1.0
    ast = 1.0

    assert transform(ast, %Context{}) == %IR.FloatType{value: 1.0}
  end

  describe "function definition" do
    test "name" do
      # def my_fun do
      # end
      ast = {:def, [line: 1], [{:my_fun, [line: 1], nil}, [do: {:__block__, [], []}]]}

      assert %IR.FunctionDefinition{name: :my_fun} = transform(ast, %Context{})
    end

    test "no params" do
      # def my_fun do
      # end
      ast = {:def, [line: 1], [{:my_fun, [line: 1], nil}, [do: {:__block__, [], []}]]}

      assert %IR.FunctionDefinition{arity: 0, params: []} = transform(ast, %Context{})
    end

    test "single param" do
      # def my_fun(x) do
      # end
      ast =
        {:def, [line: 1],
         [{:my_fun, [line: 1], [{:x, [line: 1], nil}]}, [do: {:__block__, [], []}]]}

      assert %IR.FunctionDefinition{arity: 1, params: [%IR.Variable{name: :x}]} =
               transform(ast, %Context{})
    end

    test "multiple params" do
      # def my_fun(x, y) do
      # end
      ast =
        {:def, [line: 1],
         [
           {:my_fun, [line: 1], [{:x, [line: 1], nil}, {:y, [line: 1], nil}]},
           [do: {:__block__, [], []}]
         ]}

      assert %IR.FunctionDefinition{
               arity: 2,
               params: [%IR.Variable{name: :x}, %IR.Variable{name: :y}]
             } = transform(ast, %Context{})
    end

    test "empty body" do
      # def my_fun do
      # end
      ast = {:def, [line: 1], [{:my_fun, [line: 1], nil}, [do: {:__block__, [], []}]]}

      assert %IR.FunctionDefinition{body: %IR.Block{expressions: []}} = transform(ast, %Context{})
    end

    test "single expression body" do
      # def my_fun do
      #   :expr_1
      # end
      ast = {:def, [line: 1], [{:my_fun, [line: 1], nil}, [do: {:__block__, [], [:expr_1]}]]}

      assert %IR.FunctionDefinition{body: %IR.Block{expressions: [%IR.AtomType{value: :expr_1}]}} =
               transform(ast, %Context{})
    end

    test "multiple expressions body" do
      # def my_fun do
      #   :expr_1
      #   :expr_2
      # end
      ast =
        {:def, [line: 1], [{:my_fun, [line: 1], nil}, [do: {:__block__, [], [:expr_1, :expr_2]}]]}

      assert %IR.FunctionDefinition{
               body: %IR.Block{
                 expressions: [%IR.AtomType{value: :expr_1}, %IR.AtomType{value: :expr_2}]
               }
             } = transform(ast, %Context{})
    end

    test "public visibility" do
      # def my_fun do
      # end
      ast = {:def, [line: 1], [{:my_fun, [line: 1], nil}, [do: {:__block__, [], []}]]}

      assert %IR.FunctionDefinition{visibility: :public} = transform(ast, %Context{})
    end

    test "private visibility" do
      # defp my_fun do
      # end
      ast = {:defp, [line: 2], [{:my_fun, [line: 2], nil}, [do: {:__block__, [], []}]]}

      assert %IR.FunctionDefinition{visibility: :private} = transform(ast, %Context{})
    end
  end

  test "integer type" do
    # 1
    ast = 1

    assert transform(ast, %Context{}) == %IR.IntegerType{value: 1}
  end

  test "list type" do
    # [1, 2]
    ast = [1, 2]

    assert transform(ast, %Context{}) == %IR.ListType{
             data: [
               %IR.IntegerType{value: 1},
               %IR.IntegerType{value: 2}
             ]
           }
  end

  describe "local function call" do
    test "without args" do
      # my_fun()
      ast = {:my_fun, [line: 1], []}

      assert transform(ast, %Context{}) == %IR.LocalFunctionCall{function: :my_fun, args: []}
    end

    test "with args" do
      # my_fun(1, 2)
      ast = {:my_fun, [line: 1], [1, 2]}

      assert transform(ast, %Context{}) == %IR.LocalFunctionCall{
               function: :my_fun,
               args: [
                 %IR.IntegerType{value: 1},
                 %IR.IntegerType{value: 2}
               ]
             }
    end
  end

  describe "macro definition" do
    test "public" do
      # defmacro my_macro do
      #   quote do
      #     :expr
      #   end
      # end
      ast =
        {:defmacro, [line: 2],
         [
           {:my_macro, [line: 2], nil},
           [
             do: {:__block__, [], [{:quote, [line: 3], [[do: {:__block__, [], [:expr]}]]}]}
           ]
         ]}

      assert transform(ast, %Context{}) == %IR.IgnoredExpression{type: :public_macro_definition}
    end

    test "private" do
      # defmacrop my_macro do
      #   quote do
      #     :expr
      #   end
      # end
      ast =
        {:defmacrop, [line: 2],
         [
           {:my_macro, [line: 2], nil},
           [
             do: {:__block__, [], [{:quote, [line: 3], [[do: {:__block__, [], [:expr]}]]}]}
           ]
         ]}

      assert transform(ast, %Context{}) == %IR.IgnoredExpression{type: :private_macro_definition}
    end
  end

  describe "map type " do
    test "without cons operator" do
      # %{a: 1, b: 2}
      ast = {:%{}, [line: 1], [a: 1, b: 2]}

      assert transform(ast, %Context{}) == %IR.MapType{
               data: [
                 {%IR.AtomType{value: :a}, %IR.IntegerType{value: 1}},
                 {%IR.AtomType{value: :b}, %IR.IntegerType{value: 2}}
               ]
             }
    end

    test "with cons operator" do
      # %{x | a: 1, b: 2}
      ast = {:%{}, [line: 1], [{:|, [line: 1], [{:x, [line: 1], nil}, [a: 1, b: 2]]}]}

      assert transform(ast, %Context{}) == %IR.RemoteFunctionCall{
               module: %IR.AtomType{value: Map},
               function: :merge,
               args: [
                 %IR.Variable{name: :x},
                 %IR.MapType{
                   data: [
                     %IR.TupleType{
                       data: [
                         %IR.AtomType{value: :a},
                         %IR.IntegerType{value: 1}
                       ]
                     },
                     %IR.TupleType{
                       data: [
                         %IR.AtomType{value: :b},
                         %IR.IntegerType{value: 2}
                       ]
                     }
                   ]
                 }
               ]
             }
    end
  end

  test "match operator" do
    # %{a: x, b: y} = %{a: 1, b: 2}
    ast =
      {:=, [line: 1],
       [
         {:%{}, [line: 1], [a: {:x, [line: 1], nil}, b: {:y, [line: 1], nil}]},
         {:%{}, [line: 1], [a: 1, b: 2]}
       ]}

    assert transform(ast, %Context{}) == %IR.MatchOperator{
             left: %IR.MapType{
               data: [
                 {%IR.AtomType{value: :a}, %IR.Variable{name: :x}},
                 {%IR.AtomType{value: :b}, %IR.Variable{name: :y}}
               ]
             },
             right: %IR.MapType{
               data: [
                 {%IR.AtomType{value: :a}, %IR.IntegerType{value: 1}},
                 {%IR.AtomType{value: :b}, %IR.IntegerType{value: 2}}
               ]
             }
           }
  end

  test "match placeholder" do
    # _abc
    ast = {:_abc, [line: 1], nil}

    assert transform(ast, %Context{}) == %IR.MatchPlaceholder{}
  end

  describe "module" do
    test "when first alias segment is not 'Elixir'" do
      # Aaa.Bbb
      ast = {:__aliases__, [line: 1], [:Aaa, :Bbb]}

      assert transform(ast, %Context{}) == %IR.AtomType{value: :"Elixir.Aaa.Bbb"}
    end

    test "when first alias segment is 'Elixir'" do
      # Elixir.Aaa.Bbb
      ast = {:__aliases__, [line: 1], [Elixir, :Aaa, :Bbb]}

      assert transform(ast, %Context{}) == %IR.AtomType{value: :"Elixir.Aaa.Bbb"}
    end
  end

  test "module attribute operator" do
    # @my_attr
    ast = {:@, [line: 1], [{:my_attr, [line: 1], nil}]}

    assert transform(ast, %Context{}) == %IR.ModuleAttributeOperator{name: :my_attr}
  end

  describe "module definition" do
    test "empty body" do
      # defmodule Aaa.Bbb do end
      ast =
        {:defmodule, [line: 1],
         [{:__aliases__, [line: 1], [:Aaa, :Bbb]}, [do: {:__block__, [], []}]]}

      assert transform(ast, %Context{}) == %IR.ModuleDefinition{
               module: %IR.AtomType{value: Aaa.Bbb},
               body: %IR.Block{expressions: []}
             }
    end

    test "single expression body" do
      # defmodule Aaa.Bbb do
      #   :expr_1
      # end
      ast =
        {:defmodule, [line: 2],
         [{:__aliases__, [line: 2], [:Aaa, :Bbb]}, [do: {:__block__, [], [:expr_1]}]]}

      assert transform(ast, %Context{}) == %IR.ModuleDefinition{
               module: %IR.AtomType{value: Aaa.Bbb},
               body: %IR.Block{
                 expressions: [%IR.AtomType{value: :expr_1}]
               }
             }
    end

    test "multiple expressions body" do
      # defmodule Aaa.Bbb do
      #   :expr_1
      #   :expr_2
      # end
      ast =
        {:defmodule, [line: 1],
         [
           {:__aliases__, [line: 1], [:Aaa, :Bbb]},
           [do: {:__block__, [], [:expr_1, :expr_2]}]
         ]}

      assert transform(ast, %Context{}) == %IR.ModuleDefinition{
               module: %IR.AtomType{value: Aaa.Bbb},
               body: %IR.Block{
                 expressions: [
                   %IR.AtomType{value: :expr_1},
                   %IR.AtomType{value: :expr_2}
                 ]
               }
             }
    end
  end

  test "pin operator" do
    # ^my_var
    ast = {:^, [line: 1], [{:my_var, [line: 1], nil}]}

    assert transform(ast, %Context{}) == %IR.PinOperator{name: :my_var}
  end

  describe "remote function call" do
    # Remote call on variable, without args, without parenthesis case
    # is tested as part of the dot operator tests.

    test "on variable, without args, with parenthesis" do
      # a.x()
      ast = {{:., [line: 1], [{:a, [line: 1], nil}, :x]}, [line: 1], []}

      assert transform(ast, %Context{}) == %IR.RemoteFunctionCall{
               module: %IR.Variable{name: :a},
               function: :x,
               args: []
             }
    end

    test "on variable, with args" do
      # a.x(1, 2)
      ast = {{:., [line: 1], [{:a, [line: 1], nil}, :x]}, [line: 1], [1, 2]}

      assert transform(ast, %Context{}) == %IR.RemoteFunctionCall{
               module: %IR.Variable{name: :a},
               function: :x,
               args: [
                 %IR.IntegerType{value: 1},
                 %IR.IntegerType{value: 2}
               ]
             }
    end

    test "on alias, without args, without parenthesis" do
      # Abc.my_fun
      ast =
        {{:., [line: 1], [{:__aliases__, [line: 1], [:Abc]}, :my_fun]},
         [no_parens: true, line: 1], []}

      assert transform(ast, %Context{}) == %IR.RemoteFunctionCall{
               module: %IR.AtomType{value: :"Elixir.Abc"},
               function: :my_fun,
               args: []
             }
    end

    test "on alias, without args, with parenthesis" do
      # Abc.my_fun()
      ast = {{:., [line: 1], [{:__aliases__, [line: 1], [:Abc]}, :my_fun]}, [line: 1], []}

      assert transform(ast, %Context{}) == %IR.RemoteFunctionCall{
               module: %IR.AtomType{value: :"Elixir.Abc"},
               function: :my_fun,
               args: []
             }
    end

    test "on alias, with args" do
      # Abc.my_fun(1, 2)
      ast = {{:., [line: 1], [{:__aliases__, [line: 1], [:Abc]}, :my_fun]}, [line: 1], [1, 2]}

      assert transform(ast, %Context{}) == %IR.RemoteFunctionCall{
               module: %IR.AtomType{value: :"Elixir.Abc"},
               function: :my_fun,
               args: [
                 %IR.IntegerType{value: 1},
                 %IR.IntegerType{value: 2}
               ]
             }
    end

    # Remote call on module attribute, without args, without parenthesis case
    # is tested as part of the dot operator tests.

    test "on module attribute, without args" do
      # @my_attr.my_fun()
      ast =
        {{:., [line: 1], [{:@, [line: 1], [{:my_attr, [line: 1], nil}]}, :my_fun]}, [line: 1], []}

      assert transform(ast, %Context{}) == %IR.RemoteFunctionCall{
               module: %IR.ModuleAttributeOperator{name: :my_attr},
               function: :my_fun,
               args: []
             }
    end

    test "on module attribute, with args" do
      # @my_attr.my_fun(1, 2)
      ast =
        {{:., [line: 1], [{:@, [line: 1], [{:my_attr, [line: 1], nil}]}, :my_fun]}, [line: 1],
         [1, 2]}

      assert transform(ast, %Context{}) == %IR.RemoteFunctionCall{
               module: %IR.ModuleAttributeOperator{name: :my_attr},
               function: :my_fun,
               args: [
                 %IR.IntegerType{value: 1},
                 %IR.IntegerType{value: 2}
               ]
             }
    end

    # Remote call on expression, without args, without parenthesis case
    # is tested as part of the dot operator tests.

    test "on expression, without args" do
      # (anon_fun.(1, 2)).remote_fun()
      ast =
        {{:., [line: 1],
          [
            {{:., [line: 1], [{:anon_fun, [line: 1], nil}]}, [line: 1], [1, 2]},
            :remote_fun
          ]}, [line: 1], []}

      assert transform(ast, %Context{}) == %IR.RemoteFunctionCall{
               module: %IR.AnonymousFunctionCall{
                 function: %IR.Variable{name: :anon_fun},
                 args: [
                   %IR.IntegerType{value: 1},
                   %IR.IntegerType{value: 2}
                 ]
               },
               function: :remote_fun,
               args: []
             }
    end

    test "on expression, with args" do
      # (anon_fun.(1, 2)).remote_fun(3, 4)
      ast =
        {{:., [line: 1],
          [
            {{:., [line: 1], [{:anon_fun, [line: 1], nil}]}, [line: 1], [1, 2]},
            :remote_fun
          ]}, [line: 1], [3, 4]}

      assert transform(ast, %Context{}) == %IR.RemoteFunctionCall{
               module: %IR.AnonymousFunctionCall{
                 function: %IR.Variable{name: :anon_fun},
                 args: [
                   %IR.IntegerType{value: 1},
                   %IR.IntegerType{value: 2}
                 ]
               },
               function: :remote_fun,
               args: [
                 %IR.IntegerType{value: 3},
                 %IR.IntegerType{value: 4}
               ]
             }
    end

    test "on Erlang module, without args, without parenthesis" do
      # :my_module.my_fun
      ast = {{:., [line: 1], [:my_module, :my_fun]}, [no_parens: true, line: 1], []}

      assert transform(ast, %Context{}) == %IR.RemoteFunctionCall{
               module: %IR.AtomType{value: :my_module},
               function: :my_fun,
               args: []
             }
    end

    test "on Erlang module, without args, with parenthesis" do
      # :my_module.my_fun()
      ast = {{:., [line: 1], [:my_module, :my_fun]}, [line: 1], []}

      assert transform(ast, %Context{}) == %IR.RemoteFunctionCall{
               module: %IR.AtomType{value: :my_module},
               function: :my_fun,
               args: []
             }
    end

    test "on Erlang module, with args" do
      # :my_module.my_fun(1, 2)
      ast = {{:., [line: 1], [:my_module, :my_fun]}, [line: 1], [1, 2]}

      assert transform(ast, %Context{}) == %IR.RemoteFunctionCall{
               module: %IR.AtomType{value: :my_module},
               function: :my_fun,
               args: [
                 %IR.IntegerType{value: 1},
                 %IR.IntegerType{value: 2}
               ]
             }
    end
  end

  test "string type" do
    # "abc"
    ast = "abc"

    assert transform(ast, %Context{}) == %IR.StringType{value: "abc"}
  end

  describe "struct" do
    # %Aaa.Bbb{a: 1, b: 2}
    @ast {:%, [line: 1],
          [{:__aliases__, [line: 1], [:Aaa, :Bbb]}, {:%{}, [line: 1], [a: 1, b: 2]}]}

    test "without cons operator, not in pattern" do
      context = %Context{pattern?: false}

      assert transform(@ast, context) == %IR.RemoteFunctionCall{
               module: %IR.AtomType{value: Aaa.Bbb},
               function: :__struct__,
               args: [
                 %IR.ListType{
                   data: [
                     %IR.TupleType{
                       data: [
                         %IR.AtomType{value: :a},
                         %IR.IntegerType{value: 1}
                       ]
                     },
                     %IR.TupleType{
                       data: [
                         %IR.AtomType{value: :b},
                         %IR.IntegerType{value: 2}
                       ]
                     }
                   ]
                 }
               ]
             }
    end

    test "without cons operator, in pattern, with module specified" do
      context = %Context{pattern?: true}

      assert transform(@ast, context) == %IR.MapType{
               data: [
                 {%IR.AtomType{value: :__struct__}, %IR.AtomType{value: Aaa.Bbb}},
                 {%IR.AtomType{value: :a}, %IR.IntegerType{value: 1}},
                 {%IR.AtomType{value: :b}, %IR.IntegerType{value: 2}}
               ]
             }
    end

    test "without cons operator, in pattern, with match placeholder instead of module" do
      # %_{a: 1, b: 2}
      ast = {:%, [line: 1], [{:_, [line: 1], nil}, {:%{}, [line: 1], [a: 1, b: 2]}]}

      context = %Context{pattern?: true}

      assert transform(ast, context) == %IR.MapType{
               data: [
                 {%IR.AtomType{value: :__struct__}, %IR.MatchPlaceholder{}},
                 {%IR.AtomType{value: :a}, %IR.IntegerType{value: 1}},
                 {%IR.AtomType{value: :b}, %IR.IntegerType{value: 2}}
               ]
             }
    end

    # Case not possible, since it wouldn't compile:
    # test "without cons operator, not in pattern, with match placeholder instead of module"

    test "with cons operator, not in pattern" do
      # %Aaa.Bbb{x | a: 1, b: 2}
      ast =
        {:%, [line: 1],
         [
           {:__aliases__, [line: 1], [:Aaa, :Bbb]},
           {:%{}, [line: 1], [{:|, [line: 1], [{:x, [line: 1], nil}, [a: 1, b: 2]]}]}
         ]}

      context = %Context{pattern?: false}

      assert transform(ast, context) == %IR.RemoteFunctionCall{
               module: %IR.AtomType{value: Map},
               function: :merge,
               args: [
                 %IR.Variable{name: :x},
                 %IR.RemoteFunctionCall{
                   module: %IR.AtomType{value: Aaa.Bbb},
                   function: :__struct__,
                   args: [
                     %IR.ListType{
                       data: [
                         %IR.TupleType{
                           data: [
                             %IR.AtomType{value: :a},
                             %IR.IntegerType{value: 1}
                           ]
                         },
                         %IR.TupleType{
                           data: [
                             %IR.AtomType{value: :b},
                             %IR.IntegerType{value: 2}
                           ]
                         }
                       ]
                     }
                   ]
                 }
               ]
             }
    end

    # Case not possible, since it wouldn't compile:
    # test "with cons operator, in pattern"
  end

  describe "tuple type" do
    test "2-element tuple" do
      # {1, 2}
      ast = {1, 2}

      assert transform(ast, %Context{}) == %IR.TupleType{
               data: [
                 %IR.IntegerType{value: 1},
                 %IR.IntegerType{value: 2}
               ]
             }
    end

    test "non-2-element tuple" do
      # {1, 2, 3}
      ast = {:{}, [line: 1], [1, 2, 3]}

      assert transform(ast, %Context{}) == %IR.TupleType{
               data: [
                 %IR.IntegerType{value: 1},
                 %IR.IntegerType{value: 2},
                 %IR.IntegerType{value: 3}
               ]
             }
    end
  end

  test "variable" do
    # my_var
    ast = {:my_var, [line: 1], nil}

    assert transform(ast, %Context{}) == %IR.Variable{name: :my_var}
  end
end
