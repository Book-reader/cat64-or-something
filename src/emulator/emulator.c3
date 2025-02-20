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
	List{Addressable} memory;
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

bitstruct CpuFlags : Register
{
	bool zero : 0;
	bool carry : 1;
	bool overflow : 2;
	bool paging : 3;
}

struct Cpu
{
	// The address of the current instruction in memory
	Register* inst_ptr; // a pointer to regs[9];
	Register* stack_ptr; // A pointer to regs[8];
	Register* syscl_addr; // A pointer to regs[10];
	Register* syscl_ret; // A pointer to regs[11];
	CpuFlags* flags;
	Register[common::NUM_REGISTERS] regs;
	// TODO: make these a register, but have the pointer cast to a bitstruct containing these and other flags
//	bool f_zero;
	// if gt
//	bool f_carry;
}

fn void Cpu.init(&self)
{
	self.regs = {};
	self.inst_ptr = &self.regs[9];
	self.stack_ptr = &self.regs[8];
	self.syscl_addr = &self.regs[10];
	self.syscl_ret = &self.regs[11];
	self.flags = (CpuFlags*)&self.regs[12];
}

Memory mem;
// TODO: multithreading by sending data between cpu structs with an array and a mutex
//tlocal Cpu cpu;


fn int main(String[] args)
{
	Cpu cpu;
	cpu.init();
	mem.new_init(common::MEM_SIZE);
	defer mem.free();
	InstructionType test = AJMP;
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
/*		if (args[0] == "test")
		{
			prog = args[1];
		}
		else
		{*/
		prog = file::load_new(args[1])!!;
//		}
	}
	else
	{
		prog = x"340301ff00000000000000330000013c000003030101000000000000001c0000001503e8ffffffffffffff3b033a03";
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
			if ((iteration % 50000000) == 0)
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
			case NOP: cpu.inst_nop(width);

			case ADD: cpu.inst_add(width);
			case IADD: cpu.unimplemented(width);
			case ADDI: cpu.inst_addi(width);
			case IADDI: cpu.unimplemented(width);

			case SUB: cpu.unimplemented(width);
			case ISUB: cpu.unimplemented(width);
			case SUBI: cpu.inst_subi(width);
			case ISUBI: cpu.unimplemented(width);

			case MUL: cpu.unimplemented(width);
			case IMUL: cpu.unimplemented(width);
			case MULI: cpu.unimplemented(width);
			case IMULI: cpu.unimplemented(width);

			case DIV: cpu.unimplemented(width);
			case IDIV: cpu.unimplemented(width);
			case DIVI: cpu.inst_divi(width);
			case IDIVI: cpu.unimplemented(width);

			case MOD: cpu.unimplemented(width);
			case IMOD: cpu.unimplemented(width);
			case MODI: cpu.inst_modi(width);
			case IMODI: cpu.unimplemented(width);

			case JMP: cpu.inst_jmp(width);
			case JMPI: cpu.unimplemented(width);
			case AJMP: cpu.inst_ajmp(width);

			case JEQ: cpu.unimplemented(width);
			case JNE: cpu.inst_jne(width);
			case JGT: cpu.inst_jgt(width);
			case JGE: cpu.unimplemented(width);
			case JLT: cpu.unimplemented(width);
			case JLE: cpu.unimplemented(width);

			case CMP: cpu.unimplemented(width);
			case ICMP: cpu.unimplemented(width);
			case CMPI: cpu.inst_cmpi(width);
			case ICMPI: cpu.inst_icmpi(width);

			case XOR: cpu.unimplemented(width);
			case XORI: cpu.unimplemented(width);

			case AND: cpu.unimplemented(width);
			case ANDI: cpu.unimplemented(width);

			case OR: cpu.unimplemented(width);
			case ORI: cpu.unimplemented(width);

			case NOT: cpu.unimplemented(width);
			case NOTI: cpu.unimplemented(width);

			case SLL: cpu.unimplemented(width);
			case SLLI: cpu.unimplemented(width);
			case SRL: cpu.unimplemented(width);
			case SRLI: cpu.unimplemented(width);
			case SRA: cpu.unimplemented(width);
			case SRAI: cpu.unimplemented(width);

			case BSE: cpu.unimplemented(width);
			case BUS: cpu.unimplemented(width);

			case PUSH: cpu.unimplemented(width);
			case PUSHI: cpu.unimplemented(width);

			case POP: cpu.unimplemented(width);
			case POPI: cpu.unimplemented(width);

			case CALL: cpu.unimplemented(width);

			case LD: cpu.inst_ld(width);
			case LDI: cpu.inst_ldi(width);

			case SD: cpu.inst_sd(width);
			case SDI: cpu.unimplemented(width);

			case MOV: cpu.inst_mov(width);

			case RET: cpu.unimplemented(width);
			case SYSCALL: cpu.unimplemented(width);

			case EXIT: running = false;//cpu.inst_exit(width);

			case DBG: cpu.inst_dbg(width);

			case PRINT: cpu.inst_print(width);
			case PRINTI: cpu.inst_printi(width);
			case PRINTINT: cpu.inst_printint(width);

/*			case PRINTI:
			case MOV:
			case ADD:
				// TODO: add directly instead of loading both, adding, and replacing as it will be more efficient
				@each_width(width; BitWidth $width)
				{
					write_reg(0, $width, @as($typefrom($width.type), read_reg(0, $width) + read_reg(1, $width)));
				};
			case EXIT:
				running = false;
				continue;
			case NOP:
				break;
			default:
				logger::error("Instruction %s not implemented yet", inst);
				return 1;*/
		}
		// TODO: set a clock speed
		$if $feature(DELAY):
			thread::sleep(1000000);
		$endif
//		self.move_forward(inst, width);
	}
	$if $feature(PERF):
		NanoDuration nano_seconds = clock.mark(); 
		io::printfn("Took %s or %s ns to do %s iterations, %dMhz", nano_seconds, @as(long, nano_seconds), iteration, (@as(double, iteration) /	nano_seconds.to_sec() / 1000000).round() );
	$endif

	return 0;
}

fn void Cpu.inst_nop(self, BitWidth width)
{
	return;
}


fn void Cpu.inst_add(&self, BitWidth width) => @each_width(width; BitWidth $width)
{
	self.write_reg(0, $width, @as($typefrom($width.type), self.read_reg(0, $width) + self.read_reg(1, $width)));
	self.move_forward(ADD, $width);
}

fn void Cpu.inst_addi(&self, BitWidth width) => @each_width(width; BitWidth $width)
{
	self.write_reg(0, $width, @as($typefrom($width.type), self.read_reg(0, $width) + self.read_imm(1, $width)));
	self.move_forward(ADDI, $width);
}

fn void Cpu.inst_iadd(&self){unreachable();}

fn void Cpu.inst_iaddi(&self){unreachable();}


fn void Cpu.inst_subi(&self, BitWidth width) => @each_width(width; BitWidth $width)
{
	self.write_reg(0, $width, @as($typefrom($width.type), self.read_reg(0, $width) - self.read_imm(1, $width)));
	self.move_forward(SUBI, $width);
}


fn void Cpu.inst_divi(&self, BitWidth width) => @each_width(width; BitWidth $width)
{
	self.write_reg(0, $width, @as($typefrom($width.itype) , self.read_reg(0, $width) / self.read_imm(1, $width)));
	self.move_forward(DIVI, $width);
}


fn void Cpu.inst_modi(&self, BitWidth width) => @each_width(width; BitWidth $width)
{
	self.write_reg(0, $width, @as($typefrom($width.itype) , self.read_reg(0, $width) % self.read_imm(1, $width)));
	self.move_forward(MODI, $width);
}


fn void Cpu.inst_jmp(&self, BitWidth width)
{
	usz old = *self.inst_ptr;
	*self.inst_ptr += (isz)self.read_imm(0, W64);
	logger::debug("JMPing from %s to %s, difference of %s", old, *self.inst_ptr, @as(isz, *self.inst_ptr - old));
}



fn void Cpu.inst_ajmp(&self, BitWidth width) => @each_width(width; BitWidth $width)
{
	*self.inst_ptr = self.read_imm(0, $width);;
}


fn void Cpu.inst_jne(&self, BitWidth width)
{
	if (!self.flags.zero)
	{
		logger::debug("JNE true");
		usz old = *self.inst_ptr;
		*self.inst_ptr += (isz)self.read_imm(0, W64);
		logger::debug("JMPing from %s to %s, difference of %s", old, *self.inst_ptr, @as(isz, *self.inst_ptr - old));
	}
	else
	{
		logger::debug("JNE false");
		self.move_forward(JNE);
	}
}

fn void Cpu.inst_jgt(&self, BitWidth width)
{
	if (self.flags.carry)
	{
		usz old = *self.inst_ptr;
		*self.inst_ptr += (isz)self.read_imm(0, W64);
		logger::debug("JMPing from %s to %s, difference of %s", old, *self.inst_ptr, @as(isz, *self.inst_ptr - old));
	}
	else
	{
		self.move_forward(JGT);
	}
}


fn void Cpu.inst_cmpi(&self, BitWidth width) => @each_width(width; BitWidth $width)
{
	logger::debug("Comparing value %s with value in register %s (%s)", @as(isz, self.read_reg(1, $width)), self.read_imm(0, W8), self.read_reg(0, $width));
	$typefrom($width.type) src = self.read_imm(1, $width);
	$typefrom($width.type) dst = self.read_reg(0, $width);
	logger::debug("src: %s, dst: %s", src, dst);
	self.flags.zero = dst == src;
	self.flags.carry = dst > src;
	self.move_forward(CMPI, $width);
}

fn void Cpu.inst_icmpi(&self, BitWidth width) => @each_width(width; BitWidth $width)
{
	logger::debug("Comparing value %s with value in register %s (%s)", @as(isz, self.read_reg(1, $width)), self.read_imm(0, W8), self.read_reg(0, $width));
	$typefrom($width.itype) src = self.read_imm(1, $width, true);
	$typefrom($width.itype) dst = self.read_reg(0, $width, true);
	logger::debug("src: %s, dst: %s", src, dst);
	self.flags.zero = dst == src;
	self.flags.carry = dst > src;
	self.move_forward(ICMPI, $width);
}


fn void Cpu.inst_ld(&self, BitWidth width) => @each_width(width; BitWidth $width)
{
	//logger::debug("LD: '%s' <- '%s' ('%s' -> '%h')", self.read_imm(0, W8), self.read_reg(1), self.regs[self.read_reg(1)], mem.get(self.regs[self.read_reg(1)], $width));
	self.write_reg(0, $width, mem.get(self.read_reg(1, W64), $width).get($width));
	self.move_forward(LD, $width);
}

fn void Cpu.inst_ldi(&self, BitWidth width) => @each_width(width; BitWidth $width)
{
	self.write_reg(0, $width, self.read_imm(1, $width));
	self.move_forward(LDI, $width);
}


fn void Cpu.inst_sd(&self, BitWidth width) => @each_width(width; BitWidth $width)
{
	mem.get(self.read_reg(0, W64), $width).set($width, self.read_reg(1, $width));
	self.move_forward(SD, $width);
}


fn void Cpu.inst_mov(&self, BitWidth width) => @each_width(width; BitWidth $width)
{
	self.write_reg(0, $width, self.read_reg(1, $width));
	self.move_forward(MOV, $width);
}


fn void Cpu.inst_dbg(&self, BitWidth width)
{
	logger::info("-------- DBG --------");
	foreach (i, reg : self.regs)
	{
		logger::info("%s: %.16x", common::REG_NAMES[i], reg);
	}
	logger::info("---------------------");
}


fn void Cpu.inst_print(&self, BitWidth width) => @each_width(width; BitWidth $width)
{
	logger::debug("Printing char '%c' (0x%x %s)", self.read_reg(0, $width), self.read_reg(0, $width), self.read_reg(0, $width));
	io::printf("%c", self.read_reg(0, $width));
	self.move_forward(PRINT, $width);
}

fn void Cpu.inst_printi(&self, BitWidth width) => @each_width(width; BitWidth $width)
{
	logger::debug("Printing char '%c' (0x%x %s)", self.read_imm(0, $width), self.read_imm(0, $width), self.read_imm(0, $width));
	io::printf("%c", self.read_imm(0, $width));
	self.move_forward(PRINTI, $width);
}

fn void Cpu.inst_printint(&self, BitWidth width) => @each_width(width; BitWidth $width)
{
	io::printf("%d", self.read_reg(0, $width));
	self.move_forward(PRINTINT, $width);
}


fn void Cpu.unimplemented(self, BitWidth width) @deprecated("you should implement this instruction")
{
	logger::panic("Instruction %s not implemented yet", InstructionType.from_ordinal(mem.get(*self.inst_ptr - 2, 1).get(W8)).name);
}

macro invalid_instruction(...)
{
	logger::panic("Invalid instruction 0x%x %s %s %s %s", $vasplat, $vasplat);
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

macro @as_width(BitWidth $width, #expr, bool $signed = false)
{
	$if $signed:
		return @as($typefrom($width.itype), #expr);
	$else
		return @as($typefrom($width.type), #expr);
	$endif
}

macro Cpu.read_imm(&self, usz $offset, BitWidth $width, bool $signed = false)
{
	$if $signed:
		return @as($typefrom($width.itype),  mem.get(*self.inst_ptr + $offset, $width).get($width));
	$else
		return @as($typefrom($width.itype), mem.get(*self.inst_ptr + $offset, $width).get($width));
	$endif
}

<*
 @require @typeis(value, $typefrom($width.type)) ||| @typeis(value, $typefrom($width.itype))
*>
macro void Cpu.write_reg(&self, usz offset, BitWidth $width, value)
{
	self.regs[mem.get(*self.inst_ptr + offset, 1).get(W8)].write($width, value);
}

macro Cpu.read_reg(&self, usz offset, BitWidth $width, bool $signed = false)
{
	$if $signed:
		return @as($typefrom($width.itype), self.regs[mem.get(*self.inst_ptr + offset, 1).get(W8)].read($width));
	$else
		return @as($typefrom($width.type), self.regs[mem.get(*self.inst_ptr + offset, 1).get(W8)].read($width));
	$endif
}

macro Cpu.move_forward(&self, InstructionType $inst, BitWidth $width = W64)
{
	$for (var $i = 0; $i < $inst.args.count; $i++)
		$switch ($inst.args.arg[$i])
			$case REG:
				*self.inst_ptr += common::REG_SIZE;
			$case REGOFF:
				*self.inst_ptr += common::REG_SIZE + common::OFF_SIZE;
			$case IMM:
				*self.inst_ptr += $width.size;
		$endswitch
	$endfor
}

