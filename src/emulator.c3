module emulator;
import common;

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

    Instruction test = {.real = true, .type = JIF, .jif_cond = NEQ }; // {.type = CMP, .width = W8, .src_type = REGPTR, .dst_type = NUM, .offset_kind = NONE, .real = true };

    io::printfn("test: %.4x 00b6: \u00b6", (InstSize)test); 

    char[] prog;

    if (args.len > 1)
    {
        prog = file::load_new(args[1])!!;
    }
    else
    {
        prog = x"84e8 00000000000000ff 01 8588 01 00 8006 84e4 0000000000000001 01 8382 00 00 8083 000000000000000b 900a";
    }


    mem[0:prog.len] = prog;

    if (args.len > 2)
    {
        mem[0xff:args[2].len] = args[2];
    }
    else
    {
        mem[0xff:14] = "Hello, World!\n\0";
    }


    io::printf("Executing (%s b): ", prog.len);
    foreach (c : prog)
    {
        io::printf("%.2x", c);
    }
    io::printn();

    bool running = true;

    DString inst_buf;
    inst_buf.new_init();
    defer inst_buf.free();

    io::printn("Output: ");


    // io::printfn("%.4x %.4x %.4x", @common::to_usize(W16, prog[0:2]), @common::to_usize2(W16, prog[0:2]), @common::to_usize3(W16, prog[0:2]));

    while (running)
    {
        // Fetch, Decode, Execute
        // https://tobiasvl.github.io/blog/write-a-chip-8-emulator/#fetchdecodeexecute-loop
        
        // running = false;

        // Fetch & Decode the current instruction
        Instruction curr_inst = (Instruction)(InstSize)((mem[cpu.inst_ptr] << 8) + mem[cpu.inst_ptr + 1]);

        $if ($feature(DEBUG)):
            io::printfn("%.4x %s %s %s %s", (InstSize)curr_inst, curr_inst.type, curr_inst.width, curr_inst.dst_type, curr_inst.src_type);
        $else
            inst_buf.appendf("%.4x -> %s %s %s %s\n", (InstSize)curr_inst, curr_inst.type, curr_inst.width, curr_inst.dst_type, curr_inst.src_type);
        $endif

        // Big brain common::error checking
        if (!curr_inst.real)
        {
            io::eprintn("Invalid instruction");
            running = false;
            continue;
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
                                common::error("found %s", curr_inst.src_type);
                        }
                    case NUM:
                        common::error("Destination of MOV cannot be NUM");
                    default:
                        common::error("found %s", curr_inst.dst_type);
                }
            case JMP:
                cpu.inst_ptr = common::to_usize(W64, mem[cpu.inst_ptr:BitWidth.W64.size]);
            case PRINTC:
                $if ($feature(DEBUG)):
                    inst_buf.appendf("%c", common::to_usize(W64, &cpu.registers[0]));
                $else
                    io::printf("%c", common::to_usize(W64, &cpu.registers[0]));
                $endif
            case PRINT:
                io::printf("%s", (ZString)mem[common::to_usize(W64, &cpu.registers[0])..]);
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
                               common::error("found %s", curr_inst.dst_type);
                        }
                    default:
                        common::error("found %s", curr_inst.dst_type);
                }
            case CMP:
                USize src = @read(curr_inst, src_type);
                USize dst = @read(curr_inst, dst_type);

                cpu.f_zero = src == dst;
                cpu.f_carry = src > dst;

            case JIF:
                bool jmp = false;
               
                switch (curr_inst.jif_cond)
                {
                    case NEQ:
                        jmp = !cpu.f_zero;
                    default:
                        common::error("Condition %s not implemented", curr_inst.jif_cond);
                }
                if (jmp)
                {
                    cpu.inst_ptr = common::to_usize(W64, mem[cpu.inst_ptr:BitWidth.W64.size]);
                }
                else
                {
                    cpu.inst_ptr += USize.sizeof;
                }

            case EXIT:
                running = false;
            case NOP:
                break;
            default:
                common::error("Instruction %s not implemented yet", curr_inst.type);
        }
    }

    io::printn("Produced by instructions:");
    io::printf(inst_buf.str_view());

    return 0;
}

macro USize @read(Instruction* &inst, #type)
{
    USize out;
    switch (inst.#type)
    {
        case NUM:
                out = common::to_usize(inst.width, mem[cpu.inst_ptr:inst.width.size]);
                cpu.inst_ptr += inst.width.size;
        case REG:
            out = mem[cpu.inst_ptr];
            cpu.inst_ptr += 1;
        case REGPTR:
            out = common::to_usize(W64, &cpu.registers[mem[cpu.inst_ptr]]);
            cpu.inst_ptr += 1;
        default:
            common::error("found %s", inst.#type);
    }
    return out;
}

