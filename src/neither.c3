module neither;

fn void main() @if(!$feature(EMULATOR) && !$feature(ASSEMBLER))
{
    $error("You must use either 'c3c build/run emulator' or 'c3c build/run emulator'");
}
