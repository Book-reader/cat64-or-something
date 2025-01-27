# Cat64 or something

## Inspired by [Fox32](https://github.com/fox32-arch)

> [!NOTE]
> Requires the latest c3c commit (before release 0.6.7)
>
> Yes, the latest, not two commits ago, the latest commit probably fixed a bug in the compiler in a feature that I rely on so you need the *latest* commit
>
> Especially with this latest bug in `@jump`, it silently fails at runtime in unexpected ways
>
> You have been noted.

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
