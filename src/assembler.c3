module assembler;

import std::io;

fn void main(String[] args) @if($feature(ASSEMBLER))
{
    io::printn("Assembler");
}
