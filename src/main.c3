module emulator;
import std::io;

// TODO: remove
import libc;

// 16 Mib of memory
const MEM_SIZE = 0x02000000_0;

// 8 General registers
const NUM_REGISTERS = 8;

// 64 bit
def USize = ulong;

struct Cpu
{
    // The address of the current instruction in memory
    USize inst_ptr;
    char[USize.sizeof][NUM_REGISTERS] registers;
    bool f_zero;
    // TODO: research what this actually does
    bool f_carry;
}

def InstSize = ushort;

// const PTR_SIZE = 6; // 6 bytes = 281474976710655 or 256TiB of addresable memory

const OFFSET_SIZE = 6; // allows an address offset of 281474976710655. may be less with negatives

bitstruct Instruction : InstSize
{
    // There can be a max of 31 instructions, 32 including 0
    InstructionType type : 0..4;
    BitWidth width : 5..6;
    OpType src_type : 7..8;
    OpType dst_type : 9..10;
//    Condition cond : 11..13;
    OffsetKind offset_kind : 11..12;
    
    bool real : 15;
}

enum InstructionType : char
{
    // Do nothing
    NOP,
    // move PC memory address
    JMP,
    CMP,
    JZ,
    JNZ,
    ADD,
    SUB,
    // Both of these will cease to exist once I create a stdout device
    PRINTC,
    PRINT,
    //
    MOV,
    RET,
    // Temp instruction that exits the emulator
    EXIT,

    AND,
    NAND,
    NOT,
    OR,
    XOR,
    NOR,
    XNOR,
}

enum BitWidth : char (char size)
{
    W8 = 1,
    W16 = 2,
    W32 = 4,
    W64 = 8,
}

enum OpType : char
{
    PTR,
    NUM,
    REG,
    REGPTR,
}

/*
enum Condition : char
{
    NONE,
    IFEQ,
    IFNEQ,
    IFGT,
    IFGTEQ,
    IFLT,
    IFLTEQ,
}*/

enum OffsetKind : char
{
    NONE,
    SRC,
    DST,
    BOTH
}


char[MEM_SIZE] mem;//_real; //@align(4);
//char* mem = &mem_real;
Cpu cpu;

fn int main(String[] args)
{

    Instruction test = {.type = CMP, .width = W8, .src_type = REGPTR, .dst_type = NUM, .offset_kind = NONE, .real = true };

    io::printfn("test: %.4x 00b6: \u00b6", (InstSize)test); 

    char[*] prog = x"84e9 00000000000000ff 01 8589 01 00 8007 84e5 0000000000000001 01 8001 000000000000000b 900b";

//"09c7 00000000000000ff 01 0b07 01 00 0005 09c3 0000000000000001 01 0903 01 02 0501 000000000000000b 0009";
    mem[0:prog.len] = prog;

    mem[0xff:14] = "hello, world!\n\0";

    // io::printfn("%.4x == %.4x == %.2x%.2x: %s", to_usize(W16, mem[0..1]), @to_usize(W16, mem[0..1]), mem[0], mem[1], to_usize(W16, mem[0..1]) == @to_usize(W16, mem[0..1]));

/*
    usz s = $$sysclock();

    usz x;
    for (usz i = 0; i < 10000000; i++)
    {
            x += (usz)(char*)@to_bytes(i);
    }
    usz e = $$sysclock();
    io::printfn("to_bytes: %s;; %s", e - s, x);
//libc::exit(0);
    s = $$sysclock();

    x;
    for (usz i = 0; i < 10000000; i++)
    {
        x += @to_usize(W64, mem[i:8]);
    }

    e = $$sysclock();

    io::printfn(" to_usize: %s;; %s", e - s, x);
*/
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


    // io::printfn("%.4x %.4x %.4x", @to_usize(W16, prog[0:2]), @to_usize2(W16, prog[0:2]), @to_usize3(W16, prog[0:2]));

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

        // Big brain error checking
        if (!curr_inst.real)
        {
            io::eprintn("Invalid instruction");
            running = false;
            continue;
        }


        // Point at the next byte
        cpu.inst_ptr += 2;

        //@to_bytes(@to_usize(curr_inst.width, x"112233445566778899"));
        /*if (cond is false)
        {
            continue;
        }
        */

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
                                // io::printfn("setting register %d containing %x to %x", dst[0], @to_usize(W64, &cpu.registers[dst[0]]), @to_usize(curr_inst.width, src[0:curr_inst.width.size]));
                                cpu.registers[dst][BitWidth.W64.size - curr_inst.width.size:curr_inst.width.size] = to_bytes(curr_inst.width, src)[0:curr_inst.width.size];
                            case REG:
                                cpu.registers[dst] = cpu.registers[src];
                            case REGPTR:
                                cpu.registers[dst][BitWidth.W64.size - curr_inst.width.size:curr_inst.width.size] = mem[src:curr_inst.width.size];
                            default:
                                error("found %s", curr_inst.src_type);
                        }
                    default:
                        error("found %s", curr_inst.dst_type);
                }
            case JMP:
                cpu.inst_ptr = to_usize(W64, mem[cpu.inst_ptr:BitWidth.W64.size]);
            case PRINTC:
                $if ($feature(DEBUG)):
                    inst_buf.appendf("%c", to_usize(W64, &cpu.registers[0]));
                $else
                    io::printf("%c", to_usize(W64, &cpu.registers[0]));
                $endif
                if (to_usize(W64, &cpu.registers[0]) == 0)
                {io::printn("exiting hackishly (tried to print 0)\n"); running=false;}
            case PRINT:
                io::printf("%s", (ZString)mem[to_usize(W64, &cpu.registers[0])..]);
            case ADD:
                // io::printfn("%s", curr_inst.width);
                USize src = @read(curr_inst, src_type);
                USize dst = @read(curr_inst, dst_type);

                switch (curr_inst.dst_type)
                {
                    case REG:
                        switch (curr_inst.src_type)
                        {
                            case NUM:
                                //cpu.registers[]
                               cpu.registers[dst][BitWidth.W64.size - curr_inst.width.size:curr_inst.width.size] = to_bytes(curr_inst.width, to_usize(curr_inst.width, &cpu.registers[dst]) + src)[0:curr_inst.width.size];
                            default:
                               error("found %s", curr_inst.dst_type);
                        }
                    default:
                        error("found %s", curr_inst.dst_type);
                }
            case CMP:
                USize src = @read(curr_inst, src_type);
                USize dst = @read(curr_inst, dst_type);


            case EXIT:
                running = false;
            case NOP:
                break;
            default:
                error("Instruction %s not implemented yet", curr_inst.type);
        }
    }

    io::printn("Produced by instructions:");
    io::printf(inst_buf.str_view());

    return 0;
}

/*fn USize to_usize(BitWidth width, char[] src)
{
    switch (width)
    {
        case W8:
            return src[0];
        case W16:
            return ((USize)src[0] << 8) + src[1];
        case W32:
            return ((USize)src[0] << 24) + ((USize)src[1] << 16) + ((USize)src[2] << 8) + src[3];
        case W64:
            return ((USize)src[0] << 56) + ((USize)src[1] << 48) + ((USize)src[2] << 40) + ((USize)src[3] << 32) + ((USize)src[4] << 24) + ((USize)src[5] << 16) + ((USize)src[6] << 8) + src[7];
        default:
            error("%s not implimented", width);
    }
}*/

macro USize @read(Instruction* &inst, #type)
{
    USize out;
    switch (inst.#type)
    {
        case NUM:
            $if (/*inst.type == MOV && */$stringify(#type) == "src_type"):
                out = to_usize(W64, mem[cpu.inst_ptr:inst.width.size]);
                cpu.inst_ptr += inst.width.size;
            $else
                error("Destination of MOV cannot be NUM");
            $endif
        case REG:
            out = mem[cpu.inst_ptr];
            cpu.inst_ptr += 1;
        case REGPTR:
            out = to_usize(W64, &cpu.registers[mem[cpu.inst_ptr]]);
            cpu.inst_ptr += 1;
        default:
            error("found %s", inst.#type);
    }
    return out;
}

macro void error(String format, ...)
{
    $if (env::COMPILER_SAFE_MODE):
        unreachable(format, $vasplat);
    $else
        io::eprintf("ERROR: %s:%s ", $$FILE, $$LINE);
        io::eprintfn(format, $vasplat);
        libc::exit(1);
        unreachable();
    $endif
}

fn USize to_usize(BitWidth src_width, char[] src)
{
    switch (src_width)
    {
        case W8:
            return src[0];
        case W16:
            return *(USize*)(char*)char[]{src[1], src[0]};
        case W32:
            return *(USize*)(char*)char[]{src[3], src[2], src[1], src[0]};
        case W64:
            return *(USize*)(char*)char[]{src[7], src[6], src[5], src[4], src[3], src[2], src[1], src[0]};

    }
}

fn char[] to_bytes(BitWidth dst_width, USize data)
{
    // Always ulong? @to_usize why have you forsaken me?
    // io::printfn("to_bytes: %s %s", data, $typeof(data).nameof);
    char* src = (char*)&data;
    switch (dst_width)
    {
        case W8:
            return {src[0]};
        case W16:
           return {src[1], src[0]};
        case W32:
           return {src[3], src[2], src[1], src[0]};
        case W64:
            return {src[7], src[6], src[5], src[4], src[3], src[2], src[1], src[0]};
    }//$endswitch
}
