# Fox32 emulator but not done yet

## emulator for [Fox32](https://github.com/fox32-arch) except it doesn't work :O

> [!NOTE]
> Program doesn't compile?
> try this:
> ```console
> $ nix develop --impure
> ```

usage:
```
c3c build -O5 emulator
./build/emulator <input file> <cpu cycles before shutdown (optional)>
```
```
c3c build -O5 assembler (doesn't compile and probably wont ever again)
./build/assembler <input file> <output file>
```

can also be ran as:
```
c3c run emulator -- <args>
``
