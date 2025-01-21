module assembler;

import common;
import lexer;
import logger;

import std::io;
import std::collections::list;
import std::collections::tuple;

def LProg = List(<InstTok>);
def Bytes = List(<char>);

macro Bytes Bytes.new(...) @operator(construct)
{
  Bytes b;
  b.new_init($vasplat);
  return b;
}

struct InstTok(Printable)
{
  InstructionType type;
  BitWidth width;
  String label; 
  Arg arg_dst;
  Arg arg_src;
}

struct Arg
{
  inline ArgData data;
  ArgType type;
  BitWidth size;
}

union ArgData
{
  char as_NONE;
  String as_LABEL;
  String as_LABEL_DEREF;
  ulong as_PTR;
  char as_REG;
  char as_REGPTR;
  ulong as_NUM;
}

enum ArgType : char (OpType op)
{
  PTR = PTR,
  NUM = NUM,
  REG = REG,
  REGPTR = REGPTR,
  NONE = PTR,
  LABEL = NUM,
  LABEL_DEREF = PTR,
}

fn bool ArgType.relative(self)
{
  return self == LABEL || self == LABEL_DEREF;
}

fn usz InstTok.byte_offset(&self, LProg* prog, usz own_idx)
{
  usz count;
  for (int i = 0; i < own_idx; i++)
  {
    InstTok inst = prog.get(i);
    count += inst.size();
  }
  return count;
}

fn usz InstTok.size(&self)
{
// TODO: the below line causes an error, may be a bug.
//  logger::debug("sizeof %s w:%s + d:%s + s:%s", @as(InstSize, self.to_instruction()), Instruction.sizeof, self.@get_arg_size(arg_dst), self.@get_arg_size(arg_src));
  io::eprintfn("sizeof %.4x w:%s + d:%s + s:%s", @as(InstSize, self.to_instruction()), Instruction.sizeof, self.@get_arg_size(arg_dst), self.@get_arg_size(arg_src));
  return Instruction.sizeof + self.@get_arg_size(arg_dst) + self.@get_arg_size(arg_src); 
}

macro usz InstTok.@get_arg_size(&self, #arg)
{
  if ((self.type.args >= 1 && $stringify(#arg) == "arg_src") || (self.type.args >= 1 && $stringify(#arg) == "arg_dst"))
  {
    switch (self.#arg.type)
    {
      case NUM:
        return self.width.size;
        //return self.#arg.size.size;
/*      @eachif(self.width; $bitwidth)
        {
          return $bitwidth.size;
        };*/
      default:
        @eachif(self.#arg.type; $type)
        {
          $if ($type != NUM):
            return $sizeof(self.#arg.$eval("as_" +++ $type.nameof));
          $endif
        };
    }
  }
  return 0;
  //unreachable();
}

fn Bytes InstTok.to_bytes(&self, LProg* prog, usz own_idx)
{
  Bytes b = Bytes.new();
  b.add_array(common::to_bytes(W16, @as(InstSize, self.to_instruction())));

  if (self.type == JIF)
  {
//    b.add_array(common::to_bytes(W64, self.arg_src.as_NUM));
    $if $feature(DEBUG):
      char[] a = common::to_bytes(W64, self.arg_src.as_NUM);
      logger::debug("JIF Pointer");
      io::print("[DEBUG] ");
      foreach (ch : a)
      {
        io::printf("%.2x", ch);
      }
      io::printn();
    $endif
    b.add_array(common::to_bytes(W64, @as(ulong, self.resolve_label(prog, self.arg_src.as_LABEL, own_idx))));
  }
  else
  {
//    @eachif(self.arg_src.size; $size)
//    {
    logger::debug("Src: %h", common::to_bytes(self.arg_src.size, self.arg_src.as_NUM)[0:self.arg_src.size.size]);
    logger::debug("Dst: %h", common::to_bytes(self.arg_dst.size, self.arg_dst.as_NUM)[0:self.arg_dst.size.size]);
    switch (self.type.args)
    {
      case 2:
        b.add_array(common::to_bytes(self.arg_src.size, self.arg_src.as_NUM)[0:self.arg_src.size.size]);
        b.add_array(common::to_bytes(self.arg_dst.size, self.arg_dst.as_NUM)[0:self.arg_dst.size.size]);
      case 1:
        b.add_array(common::to_bytes(self.arg_src.size, self.arg_src.as_NUM)[0:self.arg_src.size.size]);
      case 0:
        break;
      default:
        logger::error("Unhandled arg count %s", self.type.args);
    }
//    };
  }
  
//  logger::error("TODO");
  return b;
}

fn Instruction InstTok.to_instruction(&self)
{
  Instruction inst;

  inst.real = true;
  inst.type = self.type;
  inst.width = self.width;

  inst.src_type = self.arg_src.type.op;
  inst.dst_type = self.arg_dst.type.op;

  OffsetKind of = NONE;
  if (self.arg_src.type.relative() && self.arg_dst.type.relative())
  {
    of = BOTH;
  }
  else if (self.arg_src.type.relative())
  {
    of = SRC;
  }
  else if (self.arg_dst.type.relative())
  {
    of = DST;
  }
  inst.offset_kind = of;
  logger::debug("Instruction %s offset_kind %s", inst.type, inst.offset_kind);

  if (self.type == JIF)
  {
    logger::debug("JIF: src %s, dst %s", self.arg_src.type, self.arg_dst.type);
    logger::debug("%s", self);
    inst.jif_cond = Condition.from_ordinal(self.arg_dst.as_NUM);
  }

/*bitstruct Instruction : InstSize @overlap
{
  // There can be a max of 31 instructions, 32 including 0
  InstructionType type : 0..4;
  BitWidth width : 5..6;
  // 
  Condition jif_cond : 7..8;
  OpType src_type : 7..9;
  OpType dst_type : 10..12;

//  Condition cond : 11..13;
  OffsetKind offset_kind : 12..13;
  
  bool real : 15;
}*/


  return inst;
}

fn isz InstTok.resolve_label(&self, LProg* prog, String name, usz own_idx)
{
  foreach (idx, i : prog)
  {
    if (i.label == name)
    {
      logger::debug("Label offset calculation: name %s, self %s, decl %s, diff %s, inst_size %s", name, self.byte_offset(prog, own_idx), i.byte_offset(prog, idx), i.byte_offset(prog, idx) - self.byte_offset(prog, own_idx), InstSize.sizeof);
      return i.byte_offset(prog, idx) - self.byte_offset(prog, own_idx) - InstSize.sizeof;
    }
  }
  logger::error("Label %s does not exist", name);
}

macro @eachif(value, $Enum = void, #attribute = null; @body($matching_value))
{
  $if $Enum.typeid == void.typeid:
    $Enum = $typeof(value);
  $endif

  return @eachif_arr(value, $Enum.values, #attribute, false; $match)
  {
    @body($match);
  };

}

macro @eachif_arr(value, $values, #attribute = null, $failable = true; @body($matching_value))
{
  $foreach ($value : $values)
    var $val_at;
    $if $stringify(#attribute) == "null":
      $val_at = $value;
    $else
      $val_at = $value.#attribute;
    $endif
//    logger::debug("comparing c:%s to r:%s", $val_at, value);
    if ($val_at == value)
    {
//      logger::debug("c:%s and r:%s match", $val_at, value);
      @body($value);
      return;
    }
  $endforeach


  $if $stringify(#attribute) == "null" ||| $failable:
    unreachable();
  $else
    return SearchResult.MISSING?;
  $endif
}

fn usz! InstTok.to_format(&self, Formatter* formatter) @dynamic
{
  usz! n = formatter.printf("%s.%s:[ ", self.type, self.width);
  $foreach ($arg : {"arg_dst", "arg_src"})
    n += formatter.printf("(%s", self.$eval($arg).type);
    @eachif(self.$eval($arg).type; $width)
    {
      $if $width == NUM:
        @eachif(self.width; $bitwidth)
        {
          n += formatter.printf("_%s:%s %s) ", $bitwidth, self.@get_arg_size($eval($arg)), self.$eval($arg).as_NUM);
        };
      $else
       n += formatter.printf(":%s %s) ", self.@get_arg_size($eval($arg)), self.$eval($arg).$eval("as_" +++ $width.nameof));
      $endif
    };

  $endforeach
  if (self.label.len > 0)
  {
    n += formatter.printf("l:%s ", self.label);
  }

  n += formatter.print("]");

  return n; 
}

fn int main(String[] args) @if($feature(ASSEMBLER))
{
  if (args.len != 3)
  {
    logger::info("must pass input file name and output file name");
    return 1;
  }
  char[] file_data = file::load_new(args[1])!!;
  File out_file = file::open(args[2], "wb")!!;

  usz data_ptr = 0;
  logger::debug("Assembling:\n---------\n%s\n---------", (String)file_data);
  Prog! lexed = lexer::lex(file_data);
  if (catch err = lexed)
  {
    logger::error("Error while lexing tokens: %s", err);
  }

  logger::debug("lexed: %s", lexed);

  LProg prog = build(lexed);
  logger::debug("built: %s", prog);

  Bytes generated = Bytes.new();
  foreach (i, tok : prog) generated.add_all(&&tok.to_bytes(&prog, i));

  $if $feature(DEBUG):
    logger::debug("generated:");
    foreach (ch : generated)
    {
      io::printf("%.2x", ch);
    }
    io::printn();
  $endif
  out_file.write(generated.array_view())!!;
  out_file.close()!!;


  return 0;
}

fn LProg build(Prog lexed)
{
  logger::debug("building %s", lexed);
  LProg prog;

  foreach (expr : lexed)
  {
    InstTok! tok = build_expr(expr);
    if (catch err = tok)
    {
      logger::error("error in expression '%s': %s", expr, err);
    }
    prog.push(tok);
  }

  return prog;
}

fault ExprError
{
  EXPECTED_INSTRUCTION,
  TOO_MANY_ARGS,
}

fn InstTok! build_expr(Expr expr)
{
  logger::debug("building expr: %s", expr);
  InstTok tok;

  usz i = 0;
  if (expr[i].type == LABEL_DECL)
  {
    tok.label = expr[0].lexme[..^2];
    i++;
  }
  if (expr[i].type != INSTRUCTION) return ExprError.EXPECTED_INSTRUCTION?;

  usz idx = expr[i].lexme.len - 1;

  bool has_size = false;
  if (try val = expr[i].lexme.index_of_char('.'))
  {
    idx = val - 1;
    has_size = true;
  }

  tok.type = @enum_from_value(InstructionType, name, expr[i].lexme[..idx])!;
  /*@eachif(expr[i].lexme[..idx], InstructionType, name; $inst_type)
  {
    tok.type = $inst_type;
  }!;*/
  logger::debug("token type: %s", tok.type);

  if (has_size)
  {
    tok.width = @enum_from_value(BitWidth, name, expr[i].lexme[idx+2..])!;
    logger::debug("token size: %s", tok.width);
  }

  if (tok.type.args > 0)
  {
    usz old_i = i+1;
    usz set_args = 0;
    for (; i < expr.len(); i++)
    {
      if (expr[i].type == ARG_SEP || i == expr.len() - 1)
      {
        Arg arg = build_arg(tok, expr.array_view()[old_i..i == expr.len()-1 ? i : i - 1])!;
        old_i = i+1;
        if (set_args >= tok.type.args)
        {
          return ExprError.TOO_MANY_ARGS?;
        }
        else if (set_args == 0)
        {
          tok.arg_dst = arg;
        }
        else if (set_args == 1)
        {
          tok.arg_src = arg;
        }
        else
        {
          logger::error("Instruction has more than two arguments");
        }
        set_args ++;
      }
    }
  }



  return tok;
}

fn Arg! build_arg(InstTok inst, Token[] arg_tok)
{
  Arg arg;
  logger::debug("building arg: %s", arg_tok);

  bool deref = false;

  usz i = 0;

  if (arg_tok[0].type == DEREF)
  {
    deref = true;
    i = 1;
  }

  if (arg_tok.len > i+1) logger::error("Too many tokens in instruction arg");

  switch (arg_tok[i].type)
  {
    case NUMBER:
      if (deref)
      {
        arg.type = PTR;
        arg.as_PTR = arg_tok[i].lexme.to_ulong()!;
      }
      else
      {
        arg.type = NUM;
        logger::debug("checking size of InstTok: %s", inst);
        @eachif(inst.width; $size)
        {
          logger::debug("InstTok size was %s", $size);
          arg.size = $size;
          arg.as_NUM = arg_tok[i].lexme.to_ulong()!;
        };
      }
    case REGISTER:
      if (deref)
      {
        arg.type = REGPTR;
        arg.as_REGPTR = @as(char, lexer::REG_NAMES[..].index_of(arg_tok[i].lexme)!);
      }
      else
      {
        arg.type = REG;
        arg.as_REG = @as(char, lexer::REG_NAMES[..].index_of(arg_tok[i].lexme)!);
      }
    case LABEL:
      if (deref)
      {
        arg.type = LABEL_DEREF;
        arg.as_LABEL_DEREF = arg_tok[i].lexme;
      }
      else
      {
        arg.type = LABEL;
        arg.as_LABEL = arg_tok[i].lexme;
      }
    default:
      logger::error("Unhandled token type: %s", arg_tok[i].type);
  }
  

  return arg;
}

/*
fn void validate_gen(List(<char>)* generated, Tokens lexed) // TODO: FIX
{

  Tokens sequence; 

  for (usz i = 0; i < lexed.len(); )
  {
    io::printfn("val: %s", lexed[i]);
    if (lexed[i].type == INSTRUCTION)
    {
      sequence.push(lexed[i]);
      i++;
      while (i < lexed.len() && lexed[i].type != INSTRUCTION)
      {
        sequence.push(lexed[i]);
        i++;
      }
      if (catch err = validate_sequence(generated, sequence))
      {
        logger::error("Error while parsing tokens '%s': %s", sequence.array_view(), err);
      }
      sequence.clear();
    }
    else if (lexed[i].type == LABEL_DECL)
    {
      lexer::labels.set(lexed[i].lexme[..lexed[i].lexme.len - 2], generated.len() + 1);
      i++;
    }
    else
    {
      logger::error("I probably did something stupid %s", lexed[i].type);
    }
  }
}

fault ValidationError
{
  TOO_MANY_ARGUMENTS,
  TOO_FEW_ARGUMENTS,
  UNKNOWN_BIT_SIZE,
  NUMBER_TOO_LARGE,
  INVALID_INSTRUCTION_SOMETHING_VERY_BROKEN,
  INVALID_ARGUMENT,
  INVALID_JIF_COND,
  GENERIC,
}

def InstT_And_Width = Tuple(<InstructionType, BitWidth>);

fn InstT_And_Width! validate_instruction(Token tok)
{
  $foreach ($instruction : InstructionType.values)
  if (tok.lexme.len >= $instruction.name.len && tok.lexme[0:$instruction.name.len] == $instruction.name)
  {
    
    if ($instruction.sized == false)
    {
      return {$instruction, W8};
    }
    USize size = tok.lexme[$instruction.name.len+1..].to_int()!;

    BitWidth width;
    switch (size)
    {
      case BitWidth.W8.bit_size:
        width = W8;
      case BitWidth.W16.bit_size:
        width = W16;
      case BitWidth.W32.bit_size:
        width = W32;
      case BitWidth.W64.bit_size:
        width = W64;
      default:
        return ValidationError.UNKNOWN_BIT_SIZE?;
    }
    return {$instruction, width};
    
    //{
    //  return true;
    //}
//    return false;
    }
  $endforeach
  return ValidationError.INVALID_INSTRUCTION_SOMETHING_VERY_BROKEN?;
}

fn List(<Tokens>)! validate_arguments(InstructionType type, Token[] args)
{
  io::printfn("args: %s", args);
  List(<Tokens>) args_val;
  Tokens collected;
  int args_count = 0;
  foreach (i, tok : args)
  {
     if (collected.len() != 0 && tok.type == ARG_SEP)
     {
       validate_argument(collected)!;
       args_val.push(collected);
       args_count ++;
       collected = {};
     }
     else if (tok.type != ARG_SEP)
     {
       collected.push(tok);
     }
  }
  if (collected.len() != 0)
  {
    validate_argument(collected)!;
    args_val.push(collected);
    args_count ++;
  }
  if (type.args_len < args_count) return ValidationError.TOO_MANY_ARGUMENTS?;
  if (type.args_len > args_count) return ValidationError.TOO_FEW_ARGUMENTS?;

  return args_val;
}

// This will eventually be used for evaluating stuff like 'mov.8 r0, [label + 5]'
fn void! validate_argument(Tokens arg)
{
   io::printfn("arg: %s", arg);
   Tokens collected;
   collected.new_init();
   defer collected.free();

   foreach (token : arg)
   {
     switch (token.type)
     {
       default:
         collected.push(token);
       case LABEL_DECL:
     }
   }
   if ( collected.len() == 1 && ( collected[0].type == CHAR || collected[0].type == NUMBER || collected[0].type == LABEL || collected[0].type == REGISTER ) ||
          ( collected.len() == 2 && collected[0].type == DEREF && ( collected[1].type == NUMBER || collected[1].type == LABEL || collected[1].type == REGISTER )))
   {
     return;
   }
   else
   {
     return ValidationError.INVALID_ARGUMENT?;
   }
}

fn Instruction! build_instruction(InstT_And_Width type, List(<Tokens>) args)
{
  Instruction inst = {.real = true, .type = type.first, .width = type.second};

  assert (args.len() <= 2);
  foreach (i, arg : args)
  {
    assert (arg.len() <= 2);
    OpType op_type;
    if (arg[0].type == DEREF)
    {
      switch (arg[1].type)
      {
        case NUMBER:
          op_type = PTR;
        case REGISTER:
          op_type = REGPTR;
        case LABEL:
          op_type = PTR;
          inst.jif_rel = true;
        default:
          logger::error("Unsupported deref: %s", arg[1].type);
      }
    }
    else
    {
      switch (arg[0].type)
      {
        case NUMBER:
        case CHAR:
          op_type = NUM;
        case REGISTER:
          op_type = REG;
        case LABEL:
          op_type = NUM;
          inst.jif_rel = true;

        default:
          logger::error("Unsupported type: %s", arg[0].type);
      }
    }
    if (i == 0)
    {
      inst.dst_type = op_type;
    }
    else
    {
      inst.src_type = op_type;
    }
  }

  if (inst.type == JIF)
  {
    int cond = args[0][0].lexme.to_int()!!;
    if (cond >= Condition.elements)
    {
      return ValidationError.INVALID_JIF_COND?;
    }
    inst.jif_cond = Condition.from_ordinal(cond);
    args.remove_first();
    if (lexer::labels.has_key(args[0][0].lexme))
    {
      inst.jif_rel = true;
    }
  }

  return inst;
}

fn void! build_arguments(List(<char>)* args_ch, InstT_And_Width inst_type, List(<Tokens>) args)
{

  if (inst_type.first == JIF)
  {
    switch (args[0][0].type)
    {
      case NUMBER:
        args_ch.add_array(common::to_bytes(W64, args[0][0].lexme.to_ulong()!));
      case LABEL:
        /*if (lexer::labels.has_key(args[0][0].lexme))
        {
          args_ch.add_array(common::to_bytes(W64, lexer::labels.get(args[0][0].lexme)!! - args_ch.len()));
        }
        else
        {
           logger::error("label does not exist: %s", args[0][0].lexme);
        }*/
        io::printfn("label offset is %d", (isz)lexer::labels.get(args[0][0].lexme)!! - args_ch.len());

io::printfn("%s %s", args_ch.array_view(), args_ch.len());
foreach (ch : args_ch)
{
  io::printf("%.2x", ch);
}
io::printn();

        io::printfn("weufhewiufewiufhewhewiufhewifuwehfiuewhfiewhf REMEMBER TO MAKE RELATIVE (isz)lexer::labels.get(args[0][0].lexme)! - args_ch.len()");
        args_ch.add_array(common::to_bytes(W64, (isz)lexer::labels.get(args[0][0].lexme)!! - args_ch.len()));

      default:
        logger::error("no");
    }
  }
  else
  {
    assert (args.len() <= 2);
    for (int i = (int)args.len() - 1; i >= 0; i--)
    {
      io::printfn("%s %s", i, args.len());
      Tokens arg = args[i];
      foreach (tok : arg)
      {
        switch (tok.type)
        {
          case REGISTER:
            args_ch.add_array(common::to_bytes(W8, lexer::REG_NAMES[..].index_of(tok.lexme)!!));
          case NUMBER:
            char[] result;
            io::printfn("%s", inst_type.second);
            switch (inst_type.second)
            {
              case W8:
                result = common::to_bytes(inst_type.second, tok.lexme.to_uchar()!, true);
              case W16:
                result = common::to_bytes(inst_type.second, tok.lexme.to_ushort()!, true);
              case W32:
                result = common::to_bytes(inst_type.second, tok.lexme.to_uint()!, true);
              case W64:
                result = common::to_bytes(inst_type.second, tok.lexme.to_ulong()!, true);
            }
            args_ch.add_array(result);
            //for ()
            io::printfn("%s: %s", inst_type.second, common::to_usize(inst_type.second, args_ch.array_view()[args_ch.len() - inst_type.second.size..]));
//            io::printfn();
          case CHAR:
             io::printfn("found char %c:%.2x", tok.lexme[0], tok.lexme[0]);
             args_ch.push(tok.lexme[0]);
             io::printfn("char2 %c %.2x", args_ch[args_ch.len()-1], args_ch[args_ch.len()-1]);
          case DEREF:
            break;
          case LABEL:
            io::printfn("label offset is %.16x", (isz)lexer::labels.get(args[0][0].lexme)!! - args_ch.len());
            io::printfn("weufhewiufewiufhewhewiufhewifuwehfiuewhfiewhf REMEMBER TO MAKE RELATIVE (isz)lexer::labels.get(tok.lexme)! - args_ch.len()");
            args_ch.add_array(common::to_bytes(W64, (isz)lexer::labels.get(args[0][0].lexme)!! - args_ch.len(), true));
          case LABEL_DECL:
            lexer::labels.set(tok.lexme[..tok.lexme.len - 2], args_ch.len() + 1);
          default:
            logger::error("Unhandled token type: %s (%s)", tok.type, tok.lexme);
        }
      }
    }
  }


}

fn void! validate_sequence(List(<char>)* data, Tokens sequence)
{
  InstT_And_Width inst_type = validate_instruction(sequence[0])!;

  List(<Tokens>) args = validate_arguments(inst_type.first, sequence.array_view()[1..])!;

  Instruction inst = build_instruction(inst_type, args)!;

  $assert(InstSize.sizeof == BitWidth.W16.size);
  data.add_array(common::to_bytes(W16, (InstSize)inst));

  build_arguments(data, inst_type, args)!; 
}
*/
