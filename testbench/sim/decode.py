from typing import Tuple, Literal
from .instr_unit import ExecType, InstrUnit
from .instr_unit import AluOpType, AluPortAType, AluPortBType
from .instr_unit import PCEffectPortAType
from .moduleConstant import *

# ---------------------------
# Bit helpers
# ---------------------------

def get_bits(x: int, hi: int, lo: int) -> int:
    mask = (1 << (hi - lo + 1)) - 1
    return (x >> lo) & mask

def sign_extend(x: int, bits: int) -> int:
    sign = 1 << (bits - 1)
    return (x ^ sign) - sign

def xname(i: int) -> str:
    return f"x{i}"

def fname(i: int) -> str:
    return f"f{i}"

def vname(n): 
    return f"v{n}"

# ---------------------------
# Immediate builders (RV32/64)
# ---------------------------

def imm_i(inst: int) -> int:
    return sign_extend(get_bits(inst, 31, 20), 12)

def imm_s(inst: int) -> int:
    v = (get_bits(inst, 31, 25) << 5) | get_bits(inst, 11, 7)
    return sign_extend(v, 12)

def imm_b(inst: int) -> int:
    b11 = get_bits(inst, 7, 7)
    b4_1 = get_bits(inst, 11, 8)
    b10_5 = get_bits(inst, 30, 25)
    b12 = get_bits(inst, 31, 31)
    v = (b12 << 12) | (b11 << 11) | (b10_5 << 5) | (b4_1 << 1)
    return sign_extend(v, 13)

def imm_u(inst: int) -> int:
    return get_bits(inst, 31, 12) << 12

def imm_j(inst: int) -> int:
    b20 = get_bits(inst, 31, 31)
    b10_1 = get_bits(inst, 30, 21)
    b11 = get_bits(inst, 20, 20)
    b19_12 = get_bits(inst, 19, 12)
    v = (b20 << 20) | (b19_12 << 12) | (b11 << 11) | (b10_1 << 1)
    return sign_extend(v, 21)

# ---------------------------
# Length detect (C vs 32-bit)
# ---------------------------

def is_compressed(inst: int) -> bool:
    # C: low2 != 0b11
    return (inst & 0x3) != 0x3

# ---------------------------
# Core decoders
# ---------------------------

class DecodeBlock():
    def __init__(self, reg, mem):
        self.reg = reg
        self.mem = mem

    def decode_32(self, inst: int, order:int = -1) -> (str, InstrUnit):
        opc = get_bits(inst, 6, 0)
        rd = get_bits(inst, 11, 7)
        funct3 = get_bits(inst, 14, 12)
        rs1 = get_bits(inst, 19, 15)
        rs2 = get_bits(inst, 24, 20)
        funct7 = get_bits(inst, 31, 25)

        # Common names
        XR = xname
        FR = fname
        VR = vname

        # Init Instr Entity
        instr = InstrUnit()

        instr.dataflow.pc = -1
        instr.order = order
        instr.dataflow.rs1 = rs1
        instr.dataflow.rs2 = rs2
        instr.dataflow.rd = rd

        # ---- LUI/AUIPC ----
        if opc == 0x37: # LUI rd, imm: rd <= (imm << 12);
            u = imm_u(inst)
            instr.alu = ExecType.ALU
            instr.op = AluOpType.ADD
            instr.dataflow.rs1 = 0
            instr.dataflow.imm = u
            instr.mux_A = AluPortAType.RS1
            instr.mux_B = AluPortBType.IMM
            return f"lui {XR(rd)}, {hex(u)}", instr
        if opc == 0x17: # AUIPC rd, imm: rd <= pc + (imm << 12);
            u = imm_u(inst)
            instr.alu = ExecType.ALU
            instr.op = AluOpType.ADD
            instr.dataflow.imm = u
            instr.mux_A = AluPortAType.PC
            instr.mux_B = AluPortBType.IMM
            return f"auipc {XR(rd)}, {hex(imm_u(inst))}", instr

        # ---- Jumps ----
        if opc == 0x6F: # JAL rd, offset: rd <= pc + 4; pc <= pc + offset
            off = imm_j(inst)
            instr.alu = ExecType.ALU
            instr.op = AluOpType.ADD
            instr.dataflow.imm = 4
            instr.dataflow.offset = off
            instr.mux_A = AluPortAType.PC
            instr.mux_B = AluPortBType.IMM
            instr.pc_effect.valid = True
            instr.pc_effect.mux_A = PCEffectPortAType.PC
            return f"jal {XR(rd)}, {hex(imm_j(inst))}", instr
        if opc == 0x67: # JALR rd, offset(rs1): rd <= pc + 4; pc <= (rs1 + offset) & ~1
            if funct3 == 0:
                off = imm_i(inst)
                instr.alu = ExecType.ALU
                instr.op = AluOpType.ADD
                instr.dataflow.imm = 4
                instr.dataflow.offset = off
                instr.mux_A = AluPortAType.PC
                instr.mux_B = AluPortBType.IMM
                instr.pc_effect.valid = True
                instr.pc_effect.mux_A = PCEffectPortAType.RS1
                return f"jalr {XR(rd)}, {hex(imm_i(inst))}({XR(rs1)})", instr
            else:
                raise NotImplementedError("Decoder: Decode Error")

        # ---- Branches ----
        if opc == 0x63:
            off = imm_b(inst)
            instr.alu = ExecType.BRANCH
            instr.op = funct3
            instr.dataflow.offset = off
            instr.pc_effect.valid = True
            instr.pc_effect.mux_A = PCEffectPortAType.PC
            m = {0: "beq", 1: "bne", 4: "blt", 5: "bge", 6: "bltu", 7: "bgeu"}
            if funct3 in m:
                return f"{m[funct3]} {XR(rs1)}, {XR(rs2)}, {hex(off)}", instr

        # ---- Loads (I) ----
        if opc == 0x03:
            off = imm_i(inst)
            instr.alu = ExecType.LSU
            instr.lsu_op = (funct3 << 2) + 0b10
            instr.dataflow.offset = off
            
            m = {
                0: "lb", 1: "lh", 2: "lw", 3: "ld", 4: "lbu", 5: "lhu", 6: "lwu"
            }
            if funct3 in m:
                return f"{m[funct3]} {XR(rd)}, {hex(off)}({XR(rs1)})", instr
            else:
                raise NotImplementedError("Decoder: Decode Error")

        # ---- Stores (S) ----
        if opc == 0x23:
            off = imm_s(inst)
            instr.alu = ExecType.LSU
            instr.lsu_op = (funct3 << 2) + 0b01
            instr.dataflow.offset = off
            m = {0: "sb", 1: "sh", 2: "sw", 3: "sd"}
            if funct3 in m:
                return f"{m[funct3]} {XR(rs2)}, {hex(off)}({XR(rs1)})"

        # ---- OP-IMM (I) ----
        if opc == 0x13:
            imm = imm_i(inst)
            shamt = shamt = get_bits(inst, 25, 20)
            opcode = (get_bits(30, 30) << 3) + funct3
            mop = {0: 'addi', 2: 'stli', 3: 'sltiu', 4: 'xori', 6: 'ori', 7: 'andi', 8: 'subi'}
            sop = {1: 'slli', 5: 'srli', 13: 'srai'}
            if opcode not in mop.keys() and opcode not in sop.keys():
                raise NotImplementedError("Decoder: Decode Error")
            if opcode in mop.keys():
                instr.alu = ExecType.ALU
                instr.mux_A = AluPortAType.RS1
                instr.mux_B = AluPortBType.IMM
                instr.dataflow.imm = imm
                return f"{mop[opcode]}, {XR(rd)}, {XR(rs1)}, {hex(imm)}", instr
            if opcode in sop.keys():
                if get_bits(inst, 31, 31) != 0 or get_bits(inst, 29, 26) != 0:
                    raise NotImplementedError("Decoder: Decode Error")
                instr.alu = ExecType.ALU
                instr.mux_A = AluPortAType.RS1
                instr.mux_B = AluPortBType.IMM
                instr.dataflow.imm = shamt
                return f"{sop[opcode]} {XR(rd)}, {XR(rs1)}, {shamt}"

        # ---- OP-IMM-32 (RV64) ----
        if opc == 0x1B:
            imm = imm_i(inst)
            shamt = get_bits(inst, 24, 20)
            opcode = (1 << 4) + (get_bits(30, 30) << 3) + funct3
            mop = {16: 'addiw'}
            sop = {17: 'slliw', 21: 'srliw', 29: 'sraiw'}
            if opcode not in mop.keys() and opcode not in sop.keys():
                raise NotImplementedError("Decoder: Decode Error")
            if opcode in mop.keys():
                instr.alu = ExecType.ALU
                instr.mux_A = AluPortAType.RS1
                instr.mux_B = AluPortBType.IMM
                instr.dataflow.imm = imm
                return f"{mop[opcode]}, {XR(rd)}, {XR(rs1)}, {hex(imm)}", instr
            if opcode in sop.keys():
                if get_bits(inst, 31, 31) != 0 or get_bits(inst, 29, 26) != 0:
                    raise NotImplementedError("Decoder: Decode Error")
                instr.alu = ExecType.ALU
                instr.mux_A = AluPortAType.RS1
                instr.mux_B = AluPortBType.IMM
                instr.dataflow.imm = shamt
                return f"{sop[opcode]} {XR(rd)}, {XR(rs1)}, {shamt}"

        # ---- OP (R) ----
        if opc == 0x33:
            opcode = (1 << 4) + (get_bits(30, 30) << 3) + funct3
            m = {
                    0: "add", 1: "sll", 2: "slt", 3: "sltu",
                    4: "xor", 5: "srl", 6: "or", 7: "and", 
                    8: "sub", 13: "sra"
                }
            if funct7 == 0x00:
                m = {
                    0: "add", 1: "sll", 2: "slt", 3: "sltu",
                    4: "xor", 5: "srl", 6: "or", 7: "and"
                }
                if funct3 in m:
                    return f"{m[funct3]} {XR(rd)}, {XR(rs1)}, {XR(rs2)}"
            if funct7 == 0x20:
                if funct3 == 0:
                    return f"sub {XR(rd)}, {XR(rs1)}, {XR(rs2)}"
                if funct3 == 5:
                    return f"sra {XR(rd)}, {XR(rs1)}, {XR(rs2)}"
            # M extension
            if funct7 == 0x01:
                m = {
                    0: "mul", 1: "mulh", 2: "mulhsu", 3: "mulhu",
                    4: "div", 5: "divu", 6: "rem", 7: "remu"
                }
                if funct3 in m:
                    return f"{m[funct3]} {XR(rd)}, {XR(rs1)}, {XR(rs2)}"

        # ---- OP-32 (RV64 R) ----
        if opc == 0x3B:
            if funct7 == 0x00:
                m = {0: "addw", 1: "sllw", 5: "srlw"}
                if funct3 in m:
                    return f"{m[funct3]} {XR(rd)}, {XR(rs1)}, {XR(rs2)}"
            if funct7 == 0x20:
                if funct3 == 0:
                    return f"subw {XR(rd)}, {XR(rs1)}, {XR(rs2)}"
                if funct3 == 5:
                    return f"sraw {XR(rd)}, {XR(rs1)}, {XR(rs2)}"
            if funct7 == 0x01:
                m = {0: "mulw", 4: "divw", 5: "divuw", 6: "remw", 7: "remuw"}
                if funct3 in m:
                    return f"{m[funct3]} {XR(rd)}, {XR(rs1)}, {XR(rs2)}"

        # ---- SYSTEM / CSR ----
        if opc == 0x73:
            if inst == 0x00000073:
                return "ecall"
            if inst == 0x00100073:
                return "ebreak"
            if funct3 in (1, 2, 3):
                m = {1: "csrrw", 2: "csrrs", 3: "csrrc"}
                csr = get_bits(inst, 31, 20)
                return f"{m[funct3]} {XR(rd)}, {hex(csr)}, {XR(rs1)}"
            if funct3 in (5, 6, 7):
                m = {5: "csrrwi", 6: "csrrsi", 7: "csrrci"}
                csr = get_bits(inst, 31, 20)
                zimm = rs1
                return f"{m[funct3]} {XR(rd)}, {hex(csr)}, {zimm}"

        # ---- FENCE ----
        if opc == 0x0F:
            if funct3 == 0:
                pred = get_bits(inst, 27, 24)
                succ = get_bits(inst, 23, 20)
                return f"fence {pred},{succ}"
            if funct3 == 1:
                return "fence.i"

        # ---- Atomic (A) LR/SC/AMO ----
        if opc == 0x2F:
            aq = get_bits(inst, 26, 26)
            rl = get_bits(inst, 25, 25)
            w_d_sel = funct3  # 2: .w, 3: .d
            suffix = ".w" if w_d_sel == 2 else (".d" if w_d_sel == 3 else "")
            amo_f5 = get_bits(inst, 31, 27)
            amo_map = {
                0b00010: "lr",
                0b00011: "sc",
                0b00001: "amoswap",
                0b00000: "amoadd",
                0b00100: "amoxor",
                0b01100: "amoand",
                0b01000: "amoor",
                0b10000: "amomin",
                0b10100: "amomax",
                0b11000: "amominu",
                0b11100: "amomaxu",
            }
            if amo_f5 in amo_map and suffix:
                amo = amo_map[amo_f5]
                ord_flag = (("aq" if aq else "") + ("" if not rl else ("rl" if not aq else ".rl"))).replace("aqrl", "aqrl")
                ord_str = f".{ord_flag}" if ord_flag else ""
                if amo in ("lr",):
                    return f"{amo}{suffix}{ord_str} {XR(rd)}, ({XR(rs1)})"
                if amo in ("sc",):
                    return f"{amo}{suffix}{ord_str} {XR(rd)}, {XR(rs2)}, ({XR(rs1)})"
                return f"{amo}{suffix}{ord_str} {XR(rd)}, {XR(rs2)}, ({XR(rs1)})"

        # ---- Floating (F/D) loads/stores ----
        if opc == 0x07:
            off = imm_i(inst)
            if funct3 == 2:
                return f"flw {FR(rd)}, {hex(off)}({XR(rs1)})"
            if funct3 == 3:
                return f"fld {FR(rd)}, {hex(off)}({XR(rs1)})"
        if opc == 0x27:
            off = imm_s(inst)
            if funct3 == 2:
                return f"fsw {FR(rs2)}, {hex(off)}({XR(rs1)})"
            if funct3 == 3:
                return f"fsd {FR(rs2)}, {hex(off)}({XR(rs1)})"

        # ---- FP fused multiply-add (F/D) ----
        if opc in (0x43, 0x47, 0x4B, 0x4F):
            # rm at funct3, fmt by funct7[1:0] via rs3 (encoded as rd for FMA family is rd, rs1, rs2, rs3)
            fmt = get_bits(inst, 26, 25)  # heuristic; real spec uses funct2 in funct7
            rs3 = get_bits(inst, 31, 27)  # approximate place for rs3 in these opcodes
            # 为了人读友好，简单用 .s / .d 判别：fmt==0 => .s, fmt==1 => .d
            suf = ".s" if fmt == 0 else (".d" if fmt == 1 else "")
            m = {0x43: "fmadd", 0x47: "fmsub", 0x4B: "fnmsub", 0x4F: "fnmadd"}
            op = m[opc] + suf if suf else m[opc]
            return f"{op} {FR(rd)}, {FR(rs1)}, {FR(rs2)}, f{rs3}"

        # ---- OP-FP (F/D) ----
        if opc == 0x53:
            rm = funct3
            # funct7 selects operation; rs2 sometimes selects conversion type
            f7 = funct7
            # Common group: fadd/sub/mul/div/sqrt.s/d
            f_scalar = {
                0x00: "fadd", 0x04: "fsub", 0x08: "fmul", 0x0C: "fdiv",
                0x2C: "fsqrt",
                0x10: "fsgnj", 0x11: "fsgnjn", 0x12: "fsgnjx",
                0x14: "fmin", 0x15: "fmax",
                0x50: "fcvt",  # fcvt.[s/d].[w/wu/l/lu] or cross s<->d
                0x60: "fcmp",  # feq/flt/fle
                0x70: "fclass/fmv"  # fclass, fmv.[x.w/w.x]
            }
            if f7 in (0x00, 0x04, 0x08, 0x0C, 0x2C):
                suf = ".s" if rs2 == 0 else (".d" if rs2 == 1 else "")
                base = f_scalar[f7] + suf if suf else f_scalar[f7]
                if f7 == 0x2C:  # fsqrt
                    return f"{base} {FR(rd)}, {FR(rs1)}"
                return f"{base} {FR(rd)}, {FR(rs1)}, {FR(rs2)}"
            if f7 in (0x10, 0x11, 0x12):  # fsgnj*
                suf = ".s" if rm == 0 else (".d" if rm == 1 else "")
                base = f_scalar[f7] + suf if suf else f_scalar[f7]
                return f"{base} {FR(rd)}, {FR(rs1)}, {FR(rs2)}"
            if f7 in (0x14, 0x15):  # fmin/fmax
                suf = ".s" if rm == 0 else (".d" if rm == 1 else "")
                base = f_scalar[f7] + suf if suf else f_scalar[f7]
                return f"{base} {FR(rd)}, {FR(rs1)}, {FR(rs2)}"
            if f7 == 0x60:  # compare
                cmp_map = {0: "feq", 1: "flt", 2: "fle"}
                if rm in cmp_map:
                    suf = ".s" if get_bits(inst, 25, 25) == 0 else ".d"
                    return f"{cmp_map[rm]}{suf} {XR(rd)}, {FR(rs1)}, {FR(rs2)}"
            if f7 == 0x70:
                # fclass (rs2=0), fmv.x.w (rs2=0) / fmv.w.x (rs2=0) — 简化处理
                if rm == 1:  # fclass
                    return f"fclass {XR(rd)}, {FR(rs1)}"
                if rm == 0:
                    # 依据位域粗略区分 x<->f 移动
                    if rs2 == 0:
                        return f"fmv.x.w {XR(rd)}, {FR(rs1)}"
                    else:
                        return f"fmv.w.x {FR(rd)}, {XR(rs1)}"
            if f7 == 0x50:
                # fcvt.*.*
                # 使用 rs2 编码目标/源类型（简化版）
                conv_map = {
                    (0, 0): "fcvt.s.w", (0, 1): "fcvt.s.wu",
                    (1, 0): "fcvt.d.w", (1, 1): "fcvt.d.wu",
                    (0, 2): "fcvt.s.l", (0, 3): "fcvt.s.lu",
                    (1, 2): "fcvt.d.l", (1, 3): "fcvt.d.lu",
                }
                key = (get_bits(inst, 25, 25), rs2 & 0x3)
                if key in conv_map:
                    return f"{conv_map[key]} {FR(rd)}, {XR(rs1)}"
                # cross precision
                if rs2 == 1 and get_bits(inst, 25, 25) == 0:
                    return f"fcvt.s.d {FR(rd)}, {FR(rs1)}"
                if rs2 == 0 and get_bits(inst, 25, 25) == 1:
                    return f"fcvt.d.s {FR(rd)}, {FR(rs1)}"

        # ---------------------------
        # Vector extension (RVV)
        # ---------------------------
        if opc == 0x57:
            # ---- Subcategory by funct3 (Table: OP-V categories)
            # 000 OPIVV   (vv)
            # 001 OPFVV   (vv, FP)
            # 010 OPMVV   (vv, moves/merges/permutation)
            # 011 OPIVI   (vi)
            # 100 OPIVX   (vx)
            # 101 OPFVF   (vf, FP)
            # 110 OPMVX   (vx, moves/merges/permutation)
            # 111 OPCFG   (vsetvli/vsetivli/vsetvl)
            sub = funct3
            vd = rd
            vs1 = rs1
            vs2 = rs2
            vm = get_bits(inst, 25, 25)
            funct6 = get_bits(inst, 31, 26)

            def vm_suffix(vm_bit):  # vm=1 -> unmasked (no suffix), vm=0 -> ", v0.t"
                return "" if vm_bit == 1 else ", v0.t"

            # ---- vsetvli / vsetivli / vsetvl (OPCFG)
            if sub == 0b111:
                uimm = get_bits(inst, 30, 20)
                # vsetivli: rs1==x0 且 rd!=x0
                if vs1 == 0 and vd != 0:
                    return f"vsetivli {xname(vd)}, {uimm}, {hex(uimm)}"
                # vsetvli: rs2==x0 且 rs1!=x0
                if vs1 != 0 and vs2 == 0:
                    return f"vsetvli {xname(vd)}, {xname(vs1)}, {hex(uimm)}"
                # vsetvl: 其余情况
                return f"vsetvl {xname(vd)}, {xname(vs1)}, {xname(vs2)}"

            # ---- Helpers: pretty print by form (vv/vx/vi, fp or int)
            def fmt_vv(name):
                return f"{name} {V(vd)}, {V(vs2)}, {V(vs1)}{vm_suffix(vm)}"

            def fmt_vx(name):
                return f"{name} {V(vd)}, {V(vs2)}, {xname(vs1)}{vm_suffix(vm)}"

            def fmt_vi(name):
                imm5 = get_bits(inst, 19, 15)  # OPIVI immediate
                return f"{name} {V(vd)}, {V(vs2)}, {imm5}{vm_suffix(vm)}"

            # ---- Integer ALU core (常用全集)
            int_map = {
                0b000000: "vadd",
                0b000010: "vsub",
                0b000011: "vrsub",          # vi: vrsub.vi
                0b000100: "vminu",
                0b000101: "vmin",
                0b000110: "vmaxu",
                0b000111: "vmax",
                0b001001: "vand",
                0b001010: "vor",
                0b001011: "vxor",
                0b001100: "vrgather",       # vv/vx；vi: vrgather.vi(别名少见)
                0b001110: "vslideup",       # vv/vx；vi: vslideup.vi
                0b001111: "vslidedown",     # vv/vx；vi: vslidedown.vi
                0b010000: "vadc",           # vv/vx
                0b010001: "vmadc",          # vv/vx/vi（vi 为 vmsbc/vmadc.vi 族）
                0b010010: "vsbc",
                0b010011: "vmsbc",
                0b010100: "vmerge",         # vv/vx/vi
                0b010111: "vmv",            # vmv.v.v/vmv.v.x/vmv.v.i（见下特殊）
                0b011000: "vsaddu",
                0b011001: "vsadd",
                0b011010: "vssubu",
                0b011011: "vssub",
                0b011100: "vdivu",
                0b011101: "vdiv",
                0b011110: "vremu",
                0b011111: "vrem",
                0b100000: "vsll",
                0b100001: "vsmul",          # 乘+舍入饱和族；部分实现可选
                0b101000: "vsrl",
                0b101001: "vsra",
                0b101011: "vnsrl",          # narrowing shifts
                0b101101: "vnsra",
                0b110000: "vmseq",
                0b110001: "vmsne",
                0b110010: "vmsltu",
                0b110011: "vmslt",
                0b110100: "vmsleu",
                0b110101: "vmsle",
                0b110111: "vmsgt",          # vi/vx 变体
                0b111000: "vminu",          # *占位：某些版本表格折叠，此处保留以便扩展*
            }

            # ---- Floating ALU core（常用全集）
            fp_map = {
                0b000000: "vfadd",
                0b000001: "vfsub",
                0b000010: "vfrsub",
                0b000011: "vfwadd",         # widen add
                0b000100: "vfmin",
                0b000101: "vfmax",
                0b000110: "vfsgnj",
                0b000111: "vfsgnjn",        # 与 vfsgnjx 按 rm/func3 决定，简单映射名见下
                0b001000: "vfsgnjx",
                0b001010: "vfmul",
                0b001011: "vfwsub",         # widen sub
                0b001100: "vfmadd",
                0b001101: "vfnmadd",
                0b001110: "vfmsub",
                0b001111: "vfnmsub",
                0b010000: "vfmacc",
                0b010001: "vfnmacc",
                0b010010: "vfmsac",
                0b010011: "vfnmsac",
                0b010100: "vfwadd",         # 另一组编码别名（不同 funct6 版本）
                0b010101: "vfdiv",
                0b010110: "vfrdiv",
                0b010111: "vfmv",           # vfmv.v.f / vfmv.f.s（见特殊）
                0b011000: "vfsqrt",
                0b011100: "vfmin",          # 兼容某些表项
                0b011101: "vfmax",
                0b100000: "vfmerge",        # vfmerge.vfm
                0b100100: "vmfeq",
                0b100101: "vmflt",
                0b100110: "vmfle",
                0b100111: "vmfne",          # 兼容别名
                0b101000: "vfclass",
                0b101001: "vfcvt",          # fp/int/宽窄转换簇（细分较多，统一名）
            }

            # ---- Moves / permutation（OPMVV/OPMVX）
            mv_perm_map = {
                0b000100: "vmerge",     # vmerge.vv / vmerge.vx
                0b000101: "vmv",        # vmv.v.v / vmv.v.x
                0b001001: "vand",
                0b001010: "vor",
                0b001011: "vxor",
                0b001100: "vrgather",
                0b001110: "vslideup",
                0b001111: "vslidedown",
                0b010000: "vadc",
                0b010001: "vmadc",
                0b010010: "vsbc",
                0b010011: "vmsbc",
                0b010100: "vmerge",
                0b010111: "vmv",
                0b100000: "vsll",
                0b101000: "vsrl",
                0b101001: "vsra",
            }

            # ---- Special cases for vmv/vfmv/vmerge/vslide1{up,down}
            def try_special():
                # vmv.v.i : OPIVI + funct6==010111
                if sub == 0b011 and funct6 == 0b010111:
                    imm5 = get_bits(inst, 19, 15)
                    return f"vmv.v.i {V(vd)}, {imm5}"
                # vmv.v.x : OPMVX + funct6==010111
                if sub == 0b110 and funct6 == 0b010111:
                    return f"vmv.v.x {V(vd)}, {xname(vs1)}"
                # vmv.v.v : OPMVV + funct6==010111
                if sub == 0b010 and funct6 == 0b010111:
                    return f"vmv.v.v {V(vd)}, {V(vs2)}"
                # vmerge.v{v,x,i}
                if funct6 == 0b010100:
                    if sub == 0b000:
                        return fmt_vv("vmerge.vv")
                    if sub == 0b100:
                        return fmt_vx("vmerge.vx")
                    if sub == 0b011:
                        return fmt_vi("vmerge.vi")
                # vslide1up/down（以 vs1 为标量源）
                if funct6 == 0b001110 and sub == 0b100:
                    return f"vslide1up.vx {V(vd)}, {V(vs2)}, {xname(vs1)}{vm_suffix(vm)}"
                if funct6 == 0b001111 and sub == 0b100:
                    return f"vslide1down.vx {V(vd)}, {V(vs2)}, {xname(vs1)}{vm_suffix(vm)}"
                # 浮点移动：vfmv.v.f（OPFVF + 010111），vfmv.f.s（OPMVV/OPMVX 变体，常见汇编别名）
                if sub == 0b101 and funct6 == 0b010111:
                    return f"vfmv.v.f {V(vd)}, {fname(vs1)}"
                return None

            sp = try_special()
            if sp is not None:
                return sp

            # ---- Dispatch by category
            if sub == 0b000:  # OPIVV
                name = int_map.get(funct6)
                if name:
                    return fmt_vv(f"{name}.vv")
                # FP vv
                name = fp_map.get(funct6)
                if name:
                    return fmt_vv(f"{name}.vv")
                # Moves/perms
                name = mv_perm_map.get(funct6)
                if name:
                    return fmt_vv(f"{name}.vv")
                return f"vop(fun6=0b{funct6:06b}).vv {V(vd)}, {V(vs2)}, {V(vs1)}{vm_suffix(vm)}"

            if sub == 0b100:  # OPIVX
                name = int_map.get(funct6)
                if name:
                    return fmt_vx(f"{name}.vx")
                name = mv_perm_map.get(funct6)
                if name:
                    return fmt_vx(f"{name}.vx")
                return f"vop(fun6=0b{funct6:06b}).vx {V(vd)}, {V(vs2)}, {xname(vs1)}{vm_suffix(vm)}"

            if sub == 0b011:  # OPIVI
                name = int_map.get(funct6)
                if name:
                    return fmt_vi(f"{name}.vi")
                return f"vop(fun6=0b{funct6:06b}).vi {V(vd)}, {V(vs2)}, {get_bits(inst,19,15)}{vm_suffix(vm)}"

            if sub == 0b001:  # OPFVV
                name = fp_map.get(funct6)
                if name:
                    return fmt_vv(f"{name}.vv")
                return f"vfop(fun6=0b{funct6:06b}).vv {V(vd)}, {V(vs2)}, {V(vs1)}{vm_suffix(vm)}"

            if sub == 0b101:  # OPFVF
                name = fp_map.get(funct6)
                if name:
                    return fmt_vx(f"{name}.vf")
                return f"vfop(fun6=0b{funct6:06b}).vf {V(vd)}, {V(vs2)}, {fname(vs1)}{vm_suffix(vm)}"

            if sub in (0b010, 0b110):  # OPMVV / OPMVX
                name = mv_perm_map.get(funct6)
                if name:
                    if sub == 0b010:
                        return fmt_vv(f"{name}.vv")
                    else:
                        return fmt_vx(f"{name}.vx")
                # 兜底
                form = ".vv" if sub == 0b010 else ".vx"
                rhs = f"{V(vs2)}, {V(vs1)}" if sub == 0b010 else f"{V(vs2)}, {xname(vs1)}"
                return f"vperm(fun6=0b{funct6:06b}){form} {V(vd)}, {rhs}{vm_suffix(vm)}"

            # 兜底（理应不会走到）
            return f".instr {{{hex(inst & 0xFFFFFFFF)}}}"

        # ---- Vector Loads / Stores (LOAD-FP / STORE-FP with vector width encoding)
        if opc in (0x07, 0x27) and funct3 == 0b111:
            # Fields according to spec:
            vm = get_bits(inst, 25, 25)
            width = get_bits(inst, 14, 12)     # EEW encoding (with mew)
            mew = get_bits(inst, 28, 28)
            mop = get_bits(inst, 27, 26)       # addressing mode
            nf = get_bits(inst, 31, 29)        # segments-1 or #whole regs-1
            off = imm_i(inst) if opc == 0x07 else imm_s(inst)
            base = xname(rs1)

            # Determine EEW and choose mnemonic stem
            def eew_text(mew, width):
                table = {
                    (0, 0b000): "8",
                    (0, 0b101): "16",
                    (0, 0b110): "32",
                    (0, 0b111): "64",
                }
                return table.get((mew, width), None)

            eew = eew_text(mew, width)
            is_load = (opc == 0x07)

            # mop: 00 unit-stride, 01 strided, 10 indexed-ordered, 11 indexed-unordered
            if mop == 0b00:
                # unit-stride / whole / mask / fault-only-first 由 lumop/sumop 指定（imm 高位）
                lumop = get_bits(inst, 24, 20)
                if is_load:
                    # mask/whole/fault-only-first
                    if lumop == 0b01001:
                        return f"vlm.v {V(rd)}, {hex(off)}({base})"
                    if lumop == 0b00100:
                        return f"vl1r.v {V(rd)}, {hex(off)}({base})"
                    if lumop == 0b10000:
                        # fault-only-first
                        if eew is None:
                            return f".instr {{{hex(inst & 0xFFFFFFFF)}}}"
                        return f"vle{eew}.ff.v {V(rd)}, {hex(off)}({base})"
                    # regular unit-stride
                    if eew is None:
                        return f".instr {{{hex(inst & 0xFFFFFFFF)}}}"
                    return f"vle{eew}.v {V(rd)}, {hex(off)}({base}){'' if vm==1 else ''}"
                else:
                    sumop = get_bits(inst, 24, 20)
                    if sumop == 0b01001:
                        return f"vsm.v {V(rs2)}, {hex(off)}({base})"
                    if sumop == 0b00100:
                        return f"vs1r.v {V(rs2)}, {hex(off)}({base})"
                    if eew is None:
                        return f".instr {{{hex(inst & 0xFFFFFFFF)}}}"
                    return f"vse{eew}.v {V(rs2)}, {hex(off)}({base})"

            if mop == 0b01:
                # strided: rs1 holds base, stride in rs2 (load) / rs2 data (store), stride in imm[??] → 规范：stride 在 rs2?（按 spec 为 x寄存器 rs2）
                if eew is None:
                    return f".instr {{{hex(inst & 0xFFFFFFFF)}}}"
                # 载入：vlseXX.v vd, (rs1), rs2 ; 存储：vsseXX.v vs2, (rs1), rs2
                if is_load:
                    return f"vlse{eew}.v {V(rd)}, ({base}), {xname(rs2)}"
                else:
                    return f"vsse{eew}.v {V(rs2)}, ({base}), {xname(get_bits(inst, 24, 20))}"

            if mop in (0b10, 0b11):
                # indexed-ordered (10) / indexed-unordered (11)
                if eew is None:
                    return f".instr {{{hex(inst & 0xFFFFFFFF)}}}"
                stem = "vloxei" if mop == 0b10 else "vluxei"
                stem_s = "vsoxei" if mop == 0b10 else "vsuxei"
                if is_load:
                    return f"{stem}{eew}.v {V(rd)}, ({base}), {V(rs2)}"
                else:
                    return f"{stem_s}{eew}.v {V(rs2)}, ({base}), {V(get_bits(inst, 24, 20))}"

            # Segmented（nf>0）：单位步长多字段（vlseg<nf>eXX / vsseg<nf>eXX）或 whole-register 多组
            if nf != 0:
                n = nf + 1
                if eew is None:
                    return f".instr {{{hex(inst & 0xFFFFFFFF)}}}"
                if is_load:
                    return f"vlseg{n}e{eew}.v {V(rd)}..{V((rd + n - 1) % 32)}, {hex(off)}({base})"
                else:
                    return f"vsseg{n}e{eew}.v {V(rs2)}..{V((rs2 + n - 1) % 32)}, {hex(off)}({base})"

            # 兜底
            return f".instr {{{hex(inst & 0xFFFFFFFF)}}}"

# ---------------------------
# Compressed (C) decoder (subset)
# ---------------------------

def decode_c(inst: int) -> str:
    op = get_bits(inst, 1, 0)
    funct3 = get_bits(inst, 15, 13)
    XR = xname

    def crx(x):  # compressed register (adds 8)
        return f"x{8 + x}"

    # Quadrant 0 (op=00)
    if op == 0b00:
        if funct3 == 0b000:
            # c.addi4spn -> addi rd', x2, nzuimm
            n = (get_bits(inst, 12, 11) << 4) | (get_bits(inst, 10, 7) << 6) | (get_bits(inst, 6, 6) << 2) | (get_bits(inst, 5, 5) << 3)
            if n == 0:
                return f".instr {{{hex(inst & 0xFFFF)}}}"
            rd_ = 8 + get_bits(inst, 4, 2)
            return f"addi {XR(rd_)}, x2, {n}"
        if funct3 == 0b010:
            # c.lw rd', uimm(xr1')
            u = (get_bits(inst, 5, 5) << 6) | (get_bits(inst, 12, 10) << 3) | (get_bits(inst, 6, 6) << 2)
            rd_ = 8 + get_bits(inst, 4, 2)
            rs1_ = 8 + get_bits(inst, 9, 7)
            return f"lw {XR(rd_)}, {u}({XR(rs1_)})"
        if funct3 == 0b011:
            # c.ld
            u = (get_bits(inst, 5, 5) << 6) | (get_bits(inst, 12, 10) << 3) | (get_bits(inst, 6, 6) << 2)
            rd_ = 8 + get_bits(inst, 4, 2)
            rs1_ = 8 + get_bits(inst, 9, 7)
            return f"ld {XR(rd_)}, {u}({XR(rs1_)})"
        if funct3 == 0b110:
            # c.sw
            u = (get_bits(inst, 5, 5) << 6) | (get_bits(inst, 12, 10) << 3) | (get_bits(inst, 6, 6) << 2)
            rs2_ = 8 + get_bits(inst, 4, 2)
            rs1_ = 8 + get_bits(inst, 9, 7)
            return f"sw {XR(rs2_)}, {u}({XR(rs1_)})"
        if funct3 == 0b111:
            # c.sd
            u = (get_bits(inst, 5, 5) << 6) | (get_bits(inst, 12, 10) << 3) | (get_bits(inst, 6, 6) << 2)
            rs2_ = 8 + get_bits(inst, 4, 2)
            rs1_ = 8 + get_bits(inst, 9, 7)
            return f"sd {XR(rs2_)}, {u}({XR(rs1_)})"

    # Quadrant 1 (op=01)
    if op == 0b01:
        if funct3 == 0b000:
            imm = sign_extend((get_bits(inst, 12, 12) << 5) | get_bits(inst, 6, 2), 6)
            rd = get_bits(inst, 11, 7)
            return "nop" if (rd == 0 and imm == 0) else f"addi {XR(rd)}, {XR(rd)}, {imm}"
        if funct3 == 0b010:
            rd = get_bits(inst, 11, 7)
            imm = sign_extend((get_bits(inst, 12, 12) << 5) | get_bits(inst, 6, 2), 6)
            return f"li {XR(rd)}, {imm}"
        if funct3 == 0b011:
            rd = get_bits(inst, 11, 7)
            imm = sign_extend((get_bits(inst, 12, 12) << 17) | (get_bits(inst, 6, 2) << 12), 18)
            if rd == 2:
                return f"addi x2, x2, {imm}"  # c.addi16sp
            return f"lui {XR(rd)}, {imm}"
        if funct3 == 0b001:
            # c.jal (RV32), treat as jal x1
            off = sign_extend(
                (get_bits(inst, 12, 12) << 11) | (get_bits(inst, 8, 8) << 10) |
                (get_bits(inst, 10, 9) << 8) | (get_bits(inst, 6, 6) << 7) |
                (get_bits(inst, 7, 7) << 6) | (get_bits(inst, 2, 2) << 5) |
                (get_bits(inst, 11, 11) << 4) | (get_bits(inst, 5, 3) << 1), 12
            )
            return f"jal x1, {off}"
        if funct3 == 0b101:
            # c.j
            off = sign_extend(
                (get_bits(inst, 12, 12) << 11) | (get_bits(inst, 8, 8) << 10) |
                (get_bits(inst, 10, 9) << 8) | (get_bits(inst, 6, 6) << 7) |
                (get_bits(inst, 7, 7) << 6) | (get_bits(inst, 2, 2) << 5) |
                (get_bits(inst, 11, 11) << 4) | (get_bits(inst, 5, 3) << 1), 12
            )
            return f"j {off}"
        if funct3 == 0b110:
            # c.beqz
            off = sign_extend(
                (get_bits(inst, 12, 12) << 8) | (get_bits(inst, 6, 5) << 6) |
                (get_bits(inst, 2, 2) << 5) | (get_bits(inst, 11, 10) << 3) |
                (get_bits(inst, 4, 3) << 1), 9
            )
            rs1_ = 8 + get_bits(inst, 9, 7)
            return f"beq {XR(rs1_)}, x0, {off}"
        if funct3 == 0b111:
            # c.bnez
            off = sign_extend(
                (get_bits(inst, 12, 12) << 8) | (get_bits(inst, 6, 5) << 6) |
                (get_bits(inst, 2, 2) << 5) | (get_bits(inst, 11, 10) << 3) |
                (get_bits(inst, 4, 3) << 1), 9
            )
            rs1_ = 8 + get_bits(inst, 9, 7)
            return f"bne {XR(rs1_)}, x0, {off}"
        if funct3 == 0b100:
            subop = get_bits(inst, 11, 10)
            rs1_ = 8 + get_bits(inst, 9, 7)
            rs2_ = 8 + get_bits(inst, 4, 2)
            if subop == 0b00:
                # c.srli
                sh = (get_bits(inst, 12, 12) << 5) | get_bits(inst, 6, 2)
                return f"srli {XR(rs1_)}, {XR(rs1_)}, {sh}"
            if subop == 0b01:
                sh = (get_bits(inst, 12, 12) << 5) | get_bits(inst, 6, 2)
                return f"srai {XR(rs1_)}, {XR(rs1_)}, {sh}"
            if subop == 0b10:
                imm = sign_extend((get_bits(inst, 12, 12) << 5) | get_bits(inst, 6, 2), 6)
                return f"andi {XR(rs1_)}, {XR(rs1_)}, {imm}"
            if subop == 0b11:
                fun = get_bits(inst, 6, 5)
                m = {0: "sub", 1: "xor", 2: "or", 3: "and"}
                if fun in m:
                    return f"{m[fun]} {XR(rs1_)}, {XR(rs1_)}, {XR(rs2_)}"

    # Quadrant 2 (op=10)
    if op == 0b10:
        if funct3 == 0b000:
            # c.slli
            rd = get_bits(inst, 11, 7)
            sh = (get_bits(inst, 12, 12) << 5) | get_bits(inst, 6, 2)
            return f"slli {XR(rd)}, {XR(rd)}, {sh}"
        if funct3 == 0b010:
            # c.lwsp
            rd = get_bits(inst, 11, 7)
            u = (get_bits(inst, 3, 2) << 6) | (get_bits(inst, 12, 12) << 5) | (get_bits(inst, 6, 4) << 2)
            return f"lw {XR(rd)}, {u}(x2)"
        if funct3 == 0b011:
            # c.ldsp
            rd = get_bits(inst, 11, 7)
            u = (get_bits(inst, 4, 2) << 6) | (get_bits(inst, 12, 12) << 5) | (get_bits(inst, 6, 5) << 3)
            return f"ld {XR(rd)}, {u}(x2)"
        if funct3 == 0b100:
            rs2 = get_bits(inst, 6, 2)
            rd = get_bits(inst, 11, 7)
            if rs2 == 0:
                if rd == 0:
                    return f".instr {{{hex(inst & 0xFFFF)}}}"
                # c.jr
                return f"jalr x0, 0({XR(rd)})"
            if rd == 0:
                return f".instr {{{hex(inst & 0xFFFF)}}}"
            if rs2 == 1 and rd == 1:
                # c.jalr (rare path)
                return f"jalr x1, 0(x1)"
            if rd == 1 and rs2 != 0:
                # c.add
                return f"add {XR(rd)}, {XR(rd)}, {XR(get_bits(inst, 6, 2))}"
            # c.mv
            return f"mv {XR(rd)}, {XR(get_bits(inst, 6, 2))}"
        if funct3 == 0b110:
            # c.swsp
            rs2 = get_bits(inst, 6, 2)
            u = (get_bits(inst, 8, 7) << 6) | (get_bits(inst, 12, 9) << 2)
            return f"sw {XR(rs2)}, {u}(x2)"
        if funct3 == 0b111:
            # c.sdsp
            rs2 = get_bits(inst, 6, 2)
            u = (get_bits(inst, 9, 7) << 6) | (get_bits(inst, 12, 10) << 3)
            return f"sd {XR(rs2)}, {u}(x2)"

    return f".instr {{{hex(inst & 0xFFFF)}}}"

# ---------------------------
# Public API
# ---------------------------

def decode_to_human(opcode: int) -> (bool, str) :
    """
    Decode a single RISC-V instruction (compressed 16b or 32b) into a human-readable string.
    Unknown patterns -> '.instr {0x...}'.
    Supports a broad subset of I/M/A/C/F/D/V; extend tables as needed.

    Args:
        opcode (int): raw instruction bits (LSB aligned). For C, pass 16-bit value; for 32b pass full 32-bit value.

    Returns:
        str
    """
    # Decide by low2 bits
    if is_compressed(opcode):
        # only keep low 16 bits for safety
        return True, decode_c(opcode & 0xFFFF)
    else:
        return False, decode_32(opcode & 0xFFFFFFFF)
    
def decode(inst: int) -> (bool, Literal[""], ):
    opc = get_bits(inst, 6, 0)
    rd = get_bits(inst, 11, 7)
    funct3 = get_bits(inst, 14, 12)
    rs1 = get_bits(inst, 19, 15)
    rs2 = get_bits(inst, 24, 20)
    funct7 = get_bits(inst, 31, 25)

    # ---- LUI/AUIPC ----
    if opc == 0x37:
        return f"lui {XR(rd)}, {hex(imm_u(inst))}"
    if opc == 0x17:
        return f"auipc {XR(rd)}, {hex(imm_u(inst))}"
