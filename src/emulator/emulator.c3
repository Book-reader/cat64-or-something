module emulator;
import common;
import logger;

import std::io;
import std::thread;
import std::time;
import std::collections::list;

struct ReadResult
{
	ulong diff;
	union
	{
		char as_W8;
		ushort as_W16;
		uint as_W32;
		ulong as_W64;
	}
}

macro ReadResult ReadResult.new(BitWidth $width, usz diff, val) @operator(construct)
{
	ReadResult new = {.diff = diff};
	new.$eval("as_" +++ $width.nameof) = val;
	return new;
}

macro ReadResult.get(self, BitWidth $width) => self.$eval("as_" +++ $width.nameof);

interface Addressable
{
	fn void free();
	fn char get(ulong address);
	fn bool contains(ulong address);
	fn void set(ulong address, char value);
	fn char[] get_range(ulong address, ulong len);
	fn bool contains_range(ulong address, ulong len);
	fn void set_range(ulong address, char[] values);
}

struct MemoryManagementUnit
{
	List<[Addressable]> memory;
}

fn MemoryManagementUnit MemoryManagementUnit.new_init() @operator(construct)
{
	MemoryManagementUnit new;
	new.memory.new_init();
	return new;
}

fn void MemoryManagementUnit.free(&self)
{
	foreach (i : self.memory)
	{
		i.free();
	}
	self.memory.free();
}

fn Addressable! MemoryManagementUnit.request(&self, ulong address)
{
	foreach (mem : self.memory)
	{
		if (mem.contains(address)) return mem;
	}
	return MemoryError.OUT_OF_BOUNDS?;
}

fn bool MemoryManagementUnit.contains(&self, ulong address) => @ok(self.request(address));

fault MemoryError
{
	OUT_OF_BOUNDS,
	NO_READ,
	NO_WRITE,
}

struct Memory// (Addressable)
{
	char[] ram;
	ulong offset;
}

fn void Memory.new_init(&self, usz size, usz offset = 0)
{
	self.offset = offset;
	self.ram = mem::new_array(char, size);
}

fn void Memory.free(&self) @dynamic
{
	mem::free(self.ram);
}

/*fn bool Memory.contains(self, ulong addr) @inline => addr - self.offset < self.ram.len;
// TODO: paging, it will also need to be a cpu flag
fn char Memory.get(self, ulong addr) @inline => self.ram[addr-self.offset:len];
fn void Memory.set(&self, ulong addr, char new) @inline => self.ram[addr-self.offset] = new;

fn bool Memory.contains_range(self, ulong start_addr, ulong len) @inline => self.contains(start_addr) && self.contains(start_addr + len - 1);
fn char[] Memory.get_range(self, ulong start_addr, ulong len) @inline => self.ram[start_addr-self.offset:len];
fn void Memory.set_range(self, ulong start_addr, ulong len, char[] new) @inline => self.ram[start_addr-self.offset:len] = new[:len];*/

fn bool Memory._contains(self, ulong addr) @inline => addr - self.offset < self.ram.len;

fn bool Memory.contains(self, ulong start_addr, ulong len) @inline => self._contains(start_addr) && self._contains(start_addr + len - 1);
fn char[] Memory.get(self, ulong start_addr, ulong len) @inline => self.ram[start_addr-self.offset:len];
fn void Memory.set(self, ulong start_addr, ulong len, char[] new) @inline => self.ram[start_addr-self.offset:len] = new[:len];

def Register = ulong;

macro Register.write(&self, BitWidth $width, data)
{
	logger::debug("Writing %s (0x%x) as %s", data, data, $width);
	self.$eval("write_" +++ $width.nameof)(data);
	logger::debug("Self is now %s (0x%x)", *self, *self);
}

fn void Register.write_W8(&self, char data) => *self = (*self & ~0x00000000000000ff) | @as(usz, data);

fn void Register.write_W16(&self, ushort data) => *self = (*self & ~0x000000000000ffff) | @as(usz, data);

fn void Register.write_W32(&self, uint data) => *self = (*self & ~0x00000000ffffffff) | @as(usz, data);

// Whoops, looks like this is a feature now
// I should probably remove this at some point
fn void Register.write_W64(&self, ulong data) => *self = ((Register) data).read_W64();


macro Register.read(&self, BitWidth $width) => self.$eval("read_" +++ $width.nameof)();

fn char Register.read_W8(self) => @as(char, self & 0x00000000000000ff);

fn ushort Register.read_W16(self) => @as(ushort, self & 0x000000000000ffff);

fn uint Register.read_W32(self) => @as(uint, self & 0x00000000ffffffff);

fn ulong Register.read_W64(self) => self;

struct Cpu
{
	// The address of the current instruction in memory
	Register* inst_ptr; // a pointer to regs[9];
	Register* stack_ptr; // A pointer to regs[8];
	Register* syscl_addr; // A pointer to regs[10];
	Register* syscl_ret; // A pointer to regs[11];
	Register[common::NUM_REGISTERS] regs;
	// TODO: make these a register, but have the pointer cast to a bitstruct containing these and other flags
	bool f_zero;
	// if gt
	bool f_carry;
}

fn void Cpu.init(&self)
{
	self.regs = {};
	self.inst_ptr = &self.regs[9];
	self.stack_ptr = &self.regs[8];
	self.syscl_addr = &self.regs[10];
	self.syscl_ret = &self.regs[11];
}

Memory mem;
// TODO: multithreading by sending data between cpu structs with an array and a mutex
tlocal Cpu cpu;


fn int main(String[] args)
{
	cpu.init();
	mem.new_init(common::MEM_SIZE);
	defer mem.free();
	InstructionType test = AJMPI;
	BitWidth test2 = W64;
//	Instruction test = {.real = true, .type = MOV, .width = W64, .src_type = REGPTR, .dst_type = REG};
//{.real = true, .type = JIF, .jif_cond = NE, .width = W8, .dst_type = NUM};//{.real = true, .type = JIF, .width = W8, .src_type = NUM, .dst_type = REG};
//{.real = true, .type = JIF, .jif_cond = NE, .offset_kind = SRC, .width = W8, .dst_type = NUM};//{.real = true, .type = MOV, .width = W64, .src_type = NUM, .dst_type = REG};
	//{.real = true, .type = JIF, .jif_cond = NE, .offset_kind = SRC, .width = W8, .src_type = PTR,.dst_type = PTR}; // {.type = CMP, .width = W8, .src_type = REGPTR, .dst_type = NUM, .offset_kind = NONE, .real = true };
//	char[2] a;
//	set_W16(&a, (InstSize)test);
	logger::debug("test: %.2x %.2x 00b6: \u00b6", test, test2);

	char[] prog;

	if (args.len > 1)
	{
		if (args[0] == "test")
		{
			prog = args[1];
		}
		else
		{
			prog = file::load_new(args[1])!!;
		}
	}
	else
	{
		prog = x"3b00 41 1403 0000000000000000 3400";//x"88e9 00000000000000ff 01 8989 01 00 88e4 0000000000000001 01 8882 00 00 8483 000000000000000b 8081 0000000000000000 800b";

				// Push test
				//x"e988 0001000000000000 08 1280 0b80";

				// Hello World (little-endian):
				// x"e988 ff00000000000000 01 8989 01 00 0680 e488 0100000000000000 01 8288 00 00 8384 0b00000000000000 0b80";

				// Hello World (big-endian)
				// x"88e9 00000000000000ff 01 8989 01 00 8006 88e4 0000000000000001 01 8882 00 00 8483 000000000000000b 800b";
				// Hello World loop
				// x"88e9 00000000000000ff 01 8989 01 00 8006 88e4 0000000000000001 01 8882 00 00 8483 000000000000000b 8081 0000000000000000 800b";

				// x"83a4 00 0000000000000000";//" 88e9 00000000000000ff 01 8989 01 00 8006 88e4 0000000000000001 01 8582 00 00 9083 000000000000000b 800b";
//				 x"88e9 00000000000000ff 01 8989 01 00 8006 88e4 0000000000000001 01 8c82 00 00 9483 ffffffffffffffe9 800b";
	}
	defer if (args.len > 1 && args[0] != "test") free(prog);


	mem.set(0, prog.len, prog);

	if (args.len > 2)
	{
		mem.set(0xff, args[2].len, args[2]);
	}
	else
	{
		String msg = "Hello, World!\n\0";
		mem.set(0xff, msg.len, msg);
	}


	logger::debug("Executing (%s b): %h", prog.len, prog);

	bool running = true;

	// io::printfn("%.4x %.4x %.4x", @common::to_usize(W16, prog[0:2]), @common::to_usize2(W16, prog[0:2]), @common::to_usize3(W16, prog[0:2]));

	$if $feature(PERF):
		usz iteration = 0;
		Clock clock = clock::now();
	$endif

	while (running)
	{
		$if $feature(PERF):
			iteration += 1;
			if ((iteration % 100000000) == 0)
			{
//				running = false; //1000000000
				NanoDuration nano_seconds = clock.mark(); 
				io::printfn("\nTook %s or %s ns to do %s iterations, %dMhz", nano_seconds, @as(long, nano_seconds), iteration, (@as(double, iteration) /	nano_seconds.to_sec() / 1000000).round() );
				thread::sleep(time::sec(1));
				iteration = 0;
				clock = clock::now();
				continue;
			}
//			if (iteration % 5000000 == 0) io::printfn("CPU Cycle: %s", iteration);
		$endif

		logger::debug("inst: %s", mem.get(*cpu.inst_ptr, 2));
		// Fetch, Decode, Execute
		// https://tobiasvl.github.io/blog/write-a-chip-8-emulator/#fetchdecodeexecute-loop
		char inst_code = mem.get(*cpu.inst_ptr, 1).get(W8);
		if (inst_code > InstructionType.elements - 1) invalid_instruction(inst_code);
		InstructionType inst = InstructionType.from_ordinal(inst_code);

		char width_code = mem.get(*cpu.inst_ptr + 1, 1).get(W8);
		if (width_code > BitWidth.elements - 1) invalid_instruction(width_code);
		BitWidth width = BitWidth.from_ordinal(width_code);


		logger::debug("%s -> %s%s (0x%.2x.0x%.2x)", *cpu.inst_ptr, inst.name, width.suffix, inst, width);
//		logger::debug("%s: %.4x -> %s.%s %s, %s", *cpu.inst_ptr, @as(InstSize, inst), inst.type, inst.width, inst.type == JIF ? inst.jif_cond.nameof : inst.dst_type.nameof, inst.src_type);


		// Big brain error checking
//		if (!inst.real)
//		{
//			logger::error("Invalid instruction: %.4x", @as(InstSize, inst));
//			running = false;
//			continue;
//		}

		// Point at the next byte
		*cpu.inst_ptr += 2;

		// Execute the current instruction
		switch (inst)
		{
			case PRINTI:
				if (width != W8)
				{
					logger::error("Only 8-bit PRINTi implemented");
					return 1;
				}
				logger::debug("Printing char '%c' (0x%x %s)", read_imm(0, W8), read_imm(0, W8), read_imm(0, W8));
				io::printf("%c", read_imm(0, W8));
				//@volatile_load(*&&read_imm(0, W8));
			case AJMPI:
				@read_immr(0, width; BitWidth $width, #val)
				{
					*cpu.inst_ptr = #val;
				};
				continue;
			case DBG:
				foreach (i, reg : cpu.regs)
				{
					logger::info("%s: %.16x", common::REG_NAMES[i], reg);
				}
			case LDI:
				@read_immr(1, width; BitWidth $width, #val)
				{
					write_reg(0, $width, #val);
				};
			case LD:
				@each_width(width; BitWidth $width)
				{
					//logger::debug("LD: '%s' <- '%s' ('%s' -> '%h')", read_imm(0, W8), read_reg(1), cpu.regs[read_reg(1)], mem.get(cpu.regs[read_reg(1)], $width));
					write_reg(0, $width, mem.get(read_reg(1, W64), $width).get($width));
				};
			case PRINT:
				if (width != W8)
				{
					logger::error("Only 8-bit PRINT implemented");
					return 1;
				}
				logger::debug("Printing char '%c' (0x%x %s)", read_reg(0, W8), read_reg(0, W8), read_reg(0, W8));
				io::printf("%c", read_reg(0, W8));
			case ADDI:
				@read_immr(1, width; BitWidth $width, #val)
				{
					write_reg(0, $width, @as($typefrom($width.type), read_reg(0, $width) + #val));
				};
			case SUBI:
				@each_width(width; BitWidth $width)
				{
					write_reg(0, $width, @as($typefrom($width.type), read_reg(0, $width) - read_imm(1, $width)));
				};
			case CMPI:
				@read_immr(1, width; BitWidth $width, #src)
				{
					logger::debug("Comparing value %s with value in register %s (%s)", @as(isz, #src), read_imm(0, W8), read_reg(0, $width));
					$typefrom($width.itype) src = ($typefrom($width.itype))#src;
					$typefrom($width.itype) dst = read_reg(0, $width);
					logger::debug("src: %s, dst: %s", src, dst);
					cpu.f_zero = src == dst;
					cpu.f_carry = src > dst;
				};
//				cpu.f_zero = src.get($width) == dst.get($width);
//				cpu.f_carry = src.get($width) > dst.get($width);
			case JNE:
				if (!cpu.f_zero)
				{
					logger::debug("JNE true");
					usz old = *cpu.inst_ptr;
					*cpu.inst_ptr += (isz)read_imm(0, W64);
					logger::debug("JMPing from %s to %s, difference of %s", old, *cpu.inst_ptr, @as(isz, *cpu.inst_ptr - old));
					continue;
				}
				else
				{
					logger::debug("JNE false");
				}
			case EXIT:
				running = false;
				continue;
			case NOP:
				break;
			default:
				logger::error("Instruction %s not implemented yet", inst);
				return 1;
		}
		// TODO: set a clock speed
		$if $feature(DELAY):
			thread::sleep(1000000);
		$endif
		move_forward(inst, width);
	}
	$if $feature(PERF):
		NanoDuration nano_seconds = clock.mark(); 
		io::printfn("Took %s or %s ns to do %s iterations, %dMhz", nano_seconds, @as(long, nano_seconds), iteration, (@as(double, iteration) /	nano_seconds.to_sec() / 1000000).round() );
	$endif

	return 0;
}

macro invalid_instruction(...)
{
	logger::panic("Invalid instruction %x %s %s %s %s", $vasplat, $vasplat);
}

macro void @each_width(BitWidth width; @body(BitWidth $width))
{
	switch (width)
	{
		case W8:
			@body(W8);
		case W16:
			@body(W16);
		case W32:
			@body(W32);
		case W64:
			@body(W64);
	}
}

macro void @read_immr(usz $offset, BitWidth width; @body(BitWidth $width, #expr)) @deprecated("Use @each_width with read_imm")
{
	switch (width)
	{
		case W8:
			@body(W8, read_imm($offset, W8));
		case W16:
			@body(W16, read_imm($offset, W16));
		case W32:
			@body(W32, read_imm($offset, W32));
		case W64:
			@body(W64, read_imm($offset, W64));
	}
}

macro read_imm(usz $offset, BitWidth $width)
{
	return mem.get(*cpu.inst_ptr + $offset, $width.size).get($width);
}

macro void write_reg(usz offset, BitWidth $width, value)
{
	cpu.regs[mem.get(*cpu.inst_ptr + offset, 1).get(W8)].write($width, value);
}

macro read_reg(usz offset, BitWidth $width)
{
	return cpu.regs[mem.get(*cpu.inst_ptr + offset, 1).get(W8)].read($width);
}

//*
//	@require inst.args.count < common::MAX_INST_ARGS
//*
fn void move_forward(InstructionType inst, BitWidth width)
{
	for (usz i = 0, usz len = inst.args.count; i < len; i++)
	{
		switch (inst.args.arg[i])
		{
			case REG:
				*cpu.inst_ptr += common::REG_SIZE;
			case REGOFF:
				*cpu.inst_ptr += common::REG_SIZE + common::OFF_SIZE;
			case IMM:
				*cpu.inst_ptr += width.size;
		}
	}
}

/*
macro vm_mov(Instruction inst, BitWidth $width)
{
	ReadResult out = read_src(inst, 0, $width);
	*cpu.inst_ptr += out.diff;
	logger::debug("MOV 1: inst_ptr += %s", out.diff);
	logger::debug("MOVing %s (0x%x)", out.get($width), out.get($width));
	usz mov = write(inst, $width, out.get($width));
	logger::debug("MOV 2: inst_ptr += %s", mov);
	*cpu.inst_ptr += mov;
}

macro vm_add(Instruction inst, BitWidth $width)
{
	ReadResult src = read_src(inst, 0, $width);
	ReadResult dst = read_dst(inst, src.diff, $width);
	logger::debug("adding %s to %s", src.get($width), dst.get($width));

	*cpu.inst_ptr += src.diff;
	(void)write(inst, $width, @as($typefrom($width.type), dst.get($width) + src.get($width)));
	*cpu.inst_ptr += dst.diff;

	logger::debug("inst_ptr after write %s", *cpu.inst_ptr);

	logger::debug("src: %x, dst: %x", src.get($width), dst.get($width));
}

macro vm_sub(Instruction inst, BitWidth $width)
{
	ReadResult src = read_src(inst, 0, $width);
	ReadResult dst = read_dst(inst, src.diff, $width);
	logger::debug("subtracting %s from %s", src.get($width), dst.get($width));

	(void)write(inst, $width, @as($typefrom($width.type), dst.get($width) - src.get($width)));
	*cpu.inst_ptr += src.diff + dst.diff;

	logger::debug("inst_ptr after write %s", *cpu.inst_ptr);

	logger::debug("src: %x, dst: %x", src.get($width), dst.get($width));
}


macro vm_cmp(Instruction inst, BitWidth $width)
{
	ReadResult src = read_src(inst, 0, $width);
	ReadResult dst = read_dst(inst, src.diff, $width);
	*cpu.inst_ptr += src.diff + dst.diff;


	logger::debug("Comparing %s and %s", src.get($width), dst.get($width));

	cpu.f_zero = src.get($width) == dst.get($width);
	cpu.f_carry = src.get($width) > dst.get($width);

	logger::debug("Equal: %s, src > dst: %s", cpu.f_zero, cpu.f_carry);
}

macro vm_and(Instruction inst, BitWidth $width)
{
	ReadResult src = read_src(inst, 0, $width);
	ReadResult dst = read_dst(inst, src.diff, $width);
	logger::debug("ANDing %s and %s", src.get($width), dst.get($width));

	(void)write(inst, $width, @as($typefrom($width.type), dst.get($width) & src.get($width)));
	*cpu.inst_ptr += src.diff + dst.diff;
}

macro vm_not(Instruction inst, BitWidth $width)
{
	// TODO: it might actually be dst_type, I cannot remember
	ReadResult src = read_src(inst, 0, $width);
	logger::debug("NOTing %s", src.get($width), );

	(void)write(inst, $width, @as($typefrom($width.type), ~ src.get($width)));
	*cpu.inst_ptr += src.diff;
}

macro vm_or(Instruction inst, BitWidth $width)
{
	ReadResult src = read_src(inst, 0, $width);
	ReadResult dst = read_dst(inst, src.diff, $width);
	logger::debug("ORing %s and %s", src.get($width), dst.get($width));

	(void)write(inst, $width, @as($typefrom($width.type), dst.get($width) | src.get($width)));
	*cpu.inst_ptr += src.diff + dst.diff;
}

macro vm_xor(Instruction inst, BitWidth $width)
{
	ReadResult src = read_src(inst, 0, $width);
	ReadResult dst = read_dst(inst, src.diff, $width);
	logger::debug("ANDing %s and %s", src.get($width), dst.get($width));

	(void)write(inst, $width, @as($typefrom($width.type), dst.get($width) ^ src.get($width)));
	*cpu.inst_ptr += src.diff + dst.diff;
}

macro vm_push(Instruction inst, BitWidth $width)
{
	*cpu.stack_ptr -= $width;
	ReadResult src = read_src(inst, 0, $width);
	*cpu.inst_ptr += src.diff;

	char[$width] buf;
	buf[..].set($width, src.get($width));
	mem.set(*cpu.stack_ptr, $width, buf[:$width]);
}

macro vm_pop(Instruction inst, BitWidth $width)
{
	*cpu.inst_ptr += write(inst, $width, mem.get(*cpu.stack_ptr, $width).get($width));
	*cpu.stack_ptr += $width;
}
fn void vm_syscall(Instruction inst)
{
	ReadResult src = read_src(inst, 0, W64);
	*cpu.inst_ptr += src.diff;
	*cpu.syscl_ret = *cpu.inst_ptr + 1;
	*cpu.inst_ptr = src.get(W64) * BitWidth.W64 + *cpu.syscl_addr;
}

fn void vm_ret(Instruction inst)
{
	*cpu.inst_ptr = mem.get(*cpu.stack_ptr, BitWidth.W64).get(W64);
}

macro write(Instruction inst, BitWidth $width, value) => @write<[$width]>(&cpu, &mem, inst, value);

macro ReadResult read_src(Instruction inst, ulong offset, BitWidth $width) => @read<[$width]>(&cpu, &mem, inst, offset, src_type);
macro ReadResult read_dst(Instruction inst, ulong offset, BitWidth $width) => @read<[$width]>(&cpu, &mem, inst, offset, dst_type);

module emulator::read_write(<WIDTH>);
import common;
import logger;

$assert($typeof(WIDTH).typeid == BitWidth.typeid && "WIDTH must be a BitWidth");

macro ReadResult @read(Cpu* cpu, Memory* mem, Instruction inst, ulong offset, #arg_type) @nodiscard @builtin
{
	logger::debug("@read: %s", inst.#arg_type);
	ulong addr =	*cpu.inst_ptr + offset;
	logger::debug("mem at addr (%s 0x%x): %h %s", addr, addr, mem.get(addr, 8), mem.get(addr, 8));
	if (!inst.$eval($stringify(#arg_type) +++ "_rel"))
	{
		switch (inst.#arg_type)
		{
			case NUM:
//				logger::debug("NUM: nearby memory: %s, number: %x", mem.get(addr, 10), mem.get(addr, WIDTH).get(WIDTH));
				return ReadResult.new(WIDTH, WIDTH, mem.get(addr, WIDTH).get(WIDTH));
			case REG:
				logger::debug("REG %s (%s) contains %.16x (8: %.2x, 16: %.4x, 32: %.8x, 64: %.16x)", common::REG_NAMES[mem.get(addr, 1).get(W8)], WIDTH, cpu.regs[mem.get(addr, 1).get(W8)], cpu.regs[mem.get(addr, 1).get(W8)].read(W8), cpu.regs[mem.get(addr, 1).get(W8)].read(W16), cpu.regs[mem.get(addr, 1).get(W8)].read(W32), cpu.regs[mem.get(addr, 1).get(W8)].read(W64));
				return ReadResult.new(WIDTH, 1, cpu.regs[mem.get(addr, 1).get(W8)].read(WIDTH));
			case REGPTR:
				logger::debug("REGPTR %s contains %.16x pointing to %h", common::REG_NAMES[mem.get(addr, 1).get(W8)], cpu.regs[mem.get(addr, 1).get(W8)], mem.get(cpu.regs[mem.get(addr, 1).get(W8)], WIDTH));
				logger::debug("Nearby REGPTR: %h", mem.get(cpu.regs[mem.get(addr, 1).get(W8)], 20));
				return ReadResult.new(WIDTH, 1, mem.get(cpu.regs[mem.get(addr, 1).get(W8)], WIDTH).get(WIDTH));
			case PTR:
				return ReadResult.new(WIDTH, BitWidth.W64, mem.get(mem.get(addr, BitWidth.W64).get(W64), WIDTH).get(WIDTH));
//			default:
//				logger::error("Not Implemented: %s", inst.dst_type);
		}
	}
	else
	{
		// TODO: call @read here and add the number returned to *cpu.inst_ptr. will need a `bool $recurse = true` in @read that is set to false the second time
		// Will still need the `$if WIDTH != W64` check
		//logger::error("Relative @read is not implemented yet");
		switch (inst.#arg_type)
		{
			case NUM:
				$if WIDTH == W64:
					return ReadResult.new(WIDTH, WIDTH, @as(long, addr) + @as(long, mem.get(addr, WIDTH).get(WIDTH)));
				$else
					logger::error("Can only read a 64 bit number relatively");
				$endif
			case PTR:
				return ReadResult.new(WIDTH, BitWidth.W64, mem.get(@as(long, addr) + @as(long, mem.get(addr, BitWidth.W64).as_W64()), WIDTH).get(WIDTH));
			case REGPTR:
				return ReadResult.new(WIDTH, 1, mem.get(@as(long, addr) + @as(long, cpu.regs[mem.get(addr, 1).as_W8()]), WIDTH).get(WIDTH));
			case REG:
				logger::error("Cannot read %s relatively (yet)", inst.#arg_type);
		}
	}
}

macro usz @write(Cpu* cpu, Memory* mem, Instruction inst, value) @nodiscard @builtin
{
	logger::debug("Writing %s (0x%x)", value, value);
	if (!inst.dst_type_rel)
	{
		switch (inst.dst_type)
		{
			case NUM:
				logger::error("Cannot MOV to NUM");
			case REG:
				logger::debug("to REG %s (%s) ", common::REG_NAMES[mem.get(*cpu.inst_ptr, 1).get(W8)], mem.get(*cpu.inst_ptr, 1).get(W8));
				cpu.regs[mem.get(*cpu.inst_ptr, 1).get(W8)].write(WIDTH, value);
				return 1;
//			case REGPTR:
			default:
				logger::error("Writing to %s is unimplemented", inst.dst_type);
		}
	}
	else
	{
		logger::error("Relative @write is not implemented yet (needed for label data)");
	}
}

