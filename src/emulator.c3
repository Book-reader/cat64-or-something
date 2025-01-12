module emulator;
import common;
import logger;

import std::io;

struct Cpu
{
    // The address of the current instruction in memory
    USize inst_ptr;
    char[USize.sizeof][common::NUM_REGISTERS] registers;
    bool f_zero;
    // if gt
    bool f_carry;
}

char[common::MEM_SIZE] mem;//_real; //@align(4);
//char* mem = &mem_real;
Cpu cpu;

fn int main(String[] args) @if($feature(EMULATOR))
{

    Instruction test = {.real = true, .type = ADD, .width = W64, .src_type = NUM, .dst_type = REG};
    //{.real = true, .type = JIF, .jif_cond = NE, .offset_kind = SRC, .width = W8, .src_type = PTR,.dst_type = PTR}; // {.type = CMP, .width = W8, .src_type = REGPTR, .dst_type = NUM, .offset_kind = NONE, .real = true };
    logger::debug("test: %.4x 00b6: \u00b6", @as(InstSize, test)); 

    char[] prog;

    if (args.len > 1)
    {
        prog = file::load_new(args[1])!!;
    }
    else
    {
        prog = x"88e8 00000000000000ff 01 8988 01 00 8006 88e4 0000000000000001 01 8582 00 00 9083 000000000000000b 800a";
    }
    defer if (args.len > 1) free(prog);


    mem[0:prog.len] = prog;

    if (args.len > 2)
    {
        mem[0xff:args[2].len] = args[2];
    }
    else
    {
        mem[0xff:14] = "Hello, World!\n\0";
    }


    $if $feature(DEBUG):
      logger::debug("Executing (%s b): ", prog.len);
      io::print("[DEBUG] ");
      foreach (c : prog)
      {
          io::printf("%.2x", c);
      }
      io::printn();
    $endif

    bool running = true;

    // io::printfn("%.4x %.4x %.4x", @common::to_usize(W16, prog[0:2]), @common::to_usize2(W16, prog[0:2]), @common::to_usize3(W16, prog[0:2]));

    while (running)
    {
        // Fetch, Decode, Execute
        // https://tobiasvl.github.io/blog/write-a-chip-8-emulator/#fetchdecodeexecute-loop
        
        // running = false;

        // Fetch & Decode the current instruction
        $echo("FIXME: " +++ $$FILE +++ ", " +++ $$FUNC);
        Instruction curr_inst = (Instruction)(InstSize)common::to_usize(W16, mem[cpu.inst_ptr:2]);

        logger::debug("%.4x -> %s %s %s %s", @as(InstSize, curr_inst), curr_inst.type, curr_inst.width, curr_inst.type == JIF ? curr_inst.jif_cond.nameof : curr_inst.dst_type.nameof, curr_inst.src_type);

        // Big brain error checking
        if (!curr_inst.real)
        {
            logger::error("Invalid instruction: %.4x", @as(InstSize, curr_inst));
//            running = false;
//            continue;
        }


        // Point at the next byte
        cpu.inst_ptr += 2;

        // Execute the current instruction
        switch (curr_inst.type)
        {
            case MOV:
                USize src = @read(curr_inst, src_type);
                USize dst = @read(curr_inst, dst_type);

                switch (curr_inst.dst_type)
                {
                    case REG:
                        switch (curr_inst.src_type)
                        {
                            case NUM:
                                // io::printfn("setting register %d containing %x to %x", dst[0], @common::to_usize(W64, &cpu.registers[dst[0]]), @common::to_usize(curr_inst.width, src[0:curr_inst.width.size]));
                                cpu.registers[dst][BitWidth.W64.size - curr_inst.width.size:curr_inst.width.size] = common::to_bytes(curr_inst.width, src)[0:curr_inst.width.size];
                            case REG:
                                cpu.registers[dst] = cpu.registers[src];
                            case REGPTR:
                                cpu.registers[dst][BitWidth.W64.size - curr_inst.width.size:curr_inst.width.size] = mem[src:curr_inst.width.size];
                            default:
                                logger::error("found %s", curr_inst.src_type);
                        }
                    case NUM:
                        logger::error("Destination of MOV cannot be NUM");
                    default:
                        logger::error("found %s", curr_inst.dst_type);
                }
            case JMP:
                cpu.inst_ptr = @read({.width = W64, .offset_kind = DST, .src_type = curr_inst.src_type, .dst_type = NUM }, dst_type);
                /*if (!curr_inst.jif_rel)
                {
                    cpu.inst_ptr = common::to_usize(W64, mem[cpu.inst_ptr:BitWidth.W64.size]);
                }
                else
                {
                    cpu.inst_ptr += (isz)common::to_usize(W64, mem[cpu.inst_ptr:BitWidth.W64.size]);
                }*/
            case PRINTC:
                io::printf("%c", common::to_usize(W64, &cpu.registers[0]));
            case PRINT:
                io::printf("%s", @as(ZString, mem[common::to_usize(W64, &cpu.registers[0])..]));
            case ADD:
                USize src = @read(curr_inst, src_type);
                USize dst = @read(curr_inst, dst_type);

                switch (curr_inst.dst_type)
                {
                    case REG:
                        switch (curr_inst.src_type)
                        {
                            case NUM:
                                //cpu.registers[]
                               cpu.registers[dst][BitWidth.W64.size - curr_inst.width.size:curr_inst.width.size] = common::to_bytes(curr_inst.width, common::to_usize(curr_inst.width, &cpu.registers[dst]) + src)[0:curr_inst.width.size];
                            default:
                               logger::error("found %s", curr_inst.dst_type);
                        }
                    default:
                        logger::error("found %s", curr_inst.dst_type);
                }
            case CMP:
                USize src = @read(curr_inst, src_type);
                USize dst = @read(curr_inst, dst_type);

                logger::debug("Comparing %s and %s", src, dst);

                cpu.f_zero = src == dst;
                cpu.f_carry = src > dst;

                logger::debug("Equal: %s, src > dst: %s", cpu.f_zero, cpu.f_carry);

            case JIF:
                bool jmp = false;

                logger::debug("Jumping with condition %s", curr_inst.jif_cond);

                switch (curr_inst.jif_cond)
                {
                    case NE:
                        logger::debug("NE: %s", !cpu.f_zero);
                        jmp = !cpu.f_zero;
                    case EQ:
                        jmp = cpu.f_zero;
                    default:
                        logger::error("Condition %s not implemented", curr_inst.jif_cond);
                }
                if (jmp)
                {
                    logger::debug("Condition was true");
                    // TODO: use the actual instruction and set the width to 64 in the assembler
                    usz old = cpu.inst_ptr;
                    cpu.inst_ptr = @read({.width = W64, .offset_kind = DST, .src_type = curr_inst.src_type, .dst_type = NUM }, dst_type);
                    logger::debug("Jumping from %s to %s", old, cpu.inst_ptr);
                }
                else
                {
                    logger::debug("Condition was false");
                    cpu.inst_ptr += USize.sizeof;
                }

            case EXIT:
                running = false;
            case NOP:
                break;
            default:
                logger::error("Instruction %s not implemented yet", curr_inst.type);
        }
    }



    return 0;
}

macro USize @read(Instruction inst, #type)
{
    usz ptr = cpu.inst_ptr;

    USize out;
    switch (inst.#type)
    {
        case NUM:
            out = common::to_usize(inst.width, mem[ptr:inst.width.size]);
            cpu.inst_ptr += inst.width.size;
        case REG:
            out = mem[ptr];
            cpu.inst_ptr += 1;
        case REGPTR:
            out = common::to_usize(W64, &cpu.registers[mem[ptr]]);
            cpu.inst_ptr += 1;
        default:
            logger::error("found %s", inst.#type);
    }

/*    var $type = $stringify(#type);
    $switch 
      $case $type == "src_type":
        if (inst.offset_kind == SRC || inst.offset_kind == BOTH)
        {
          ptr += @as(isz, out);
          return ptr;
        }
      $case $type == "dst_type":
        if (inst.offset_kind == DST || inst.offset_kind == BOTH)
        {
          ptr += @as(isz, out);
        }
        return ptr;
      $default:
        $error("@read: unsupported #type (" +++ $type +++ ")");
    $endswitch*/

    return out;
}

