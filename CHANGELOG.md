# Change Log

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](http://keepachangelog.com/), and this project adheres to
[Semantic Versioning](http://semver.org).

## Unreleased

### Fixed
- `axi_res_tbl`: Fixed assignments in `always_ff` process.
- `axi_riscv_amos`: Removed unused register.
- `axi_riscv_amos`: Added missing default assignments in AW FSM.
- `axi_riscv_amos`: Fixed sign extension of 32bit AMOs on 64bit ALU.
- `axi_riscv_amos`: Removed unused signals.
- `axi_riscv_atomics_wrap`: Fixed syntax of interface signal assignments.
- `axi_riscv_lrsc`: Added missing feedthrough of `aw_atop`.
- `axi_riscv_lrsc_wrap`: Fixed syntax of interface signal assignments.

### Added
- Added simple standalone synthesis bench for `axi_riscv_atomics`.
- Added simple standalone synthesis bench for `axi_riscv_lrsc`.

## v0.1.0 - 2019-02-19

Initial public development release
