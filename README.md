# Cat64 or something

## Inspired by [Fox32](https://github.com/fox32-arch)

> [!NOTE]
> Program doesn't compile?
> try this:
> ```console
> $ git clone https://github.com/c3lang/c3c
> $ cd c3c
> $ mkdir build
> $ cd build
> $ cmake ..
> $ cmake --build .
> ```

usage:
```
c3c build -O5 emulator
./build/emulator <input file> <string at address 0xff>
```
```
c3c build -O5 assembler
./build/assembler <input file> <output file>
```

can also be ran as:
```
c3c run <emulator/assembler> -- <args>
``
