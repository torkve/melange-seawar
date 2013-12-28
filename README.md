# Melange Seawar

This is the OCaml implementation of the seawar game using the [Melange](https://github.com/avsm/melange) as the protocol base.

Basically it is the proof of concept demonstrating how statically typed DSL for structures and network protocols can simplify
the development and debugging.

## Dependencies

* [Melange](https://github.com/avsm/melange) library, especially `splc` and `mplc` tools from it, as well as `mpl_stdlib`.
* [lablqml](https://github.com/Kakadu/lablqt/tree/qml-dev) Qt 5.2 bindings to OCaml (can be installed from OPAM)

## Installation

1. Fix the Makefile specifying proper paths to melange and your qt 5.2 installation (if it is installed not in system paths).
2. `make`

## Run

To start seawar server, run it as `./seawar --server`.

For client instance run `./seawar --host 111.222.333.444` (you can omit `--host` if it's localhost).

You can add `--ai` option for either server or client to play with AI.

## Statecalls diagram

![] https://raw.github.com/torkve/melange-seawar/master/seawar.png
