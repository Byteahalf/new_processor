def readmemh(file_name, width=128):
    """
    Read hex data (each token representing a 'width'-bit word, default 128b),
    and return a list[int] of 16-bit chunks ordered LSB->MSB:
    [15:0], [31:16], ..., [width-1 : width-16].

    - Ignores empty lines and '//' or '#' comments.
    - Accepts one or more hex tokens per line (whitespace-separated).
    - Pads/truncates each token to 'width' bits (right-aligned).
    """
    if width % 16 != 0:
        raise ValueError("width must be a multiple of 16")
    hex_digits_total = width // 4          # total hex chars per word
    hex_per_chunk = 16 // 4                # 4 hex chars per 16-bit chunk

    out = []
    with open(file_name, "r") as f:
        for raw in f:
            # strip inline comments
            line = raw.split("//", 1)[0].split("#", 1)[0].strip()
            if not line:
                continue

            # allow multiple tokens per line
            for tok in line.split():
                tok = tok.lower().removeprefix("0x").replace("_", "")
                if not tok:
                    continue
                # right-align within the declared width:
                # - if shorter, zero-pad on the left
                # - if longer, keep the rightmost bits (LSB-aligned)
                if len(tok) < hex_digits_total:
                    tok = tok.zfill(hex_digits_total)
                elif len(tok) > hex_digits_total:
                    tok = tok[-hex_digits_total:]

                # split from LSB side into 16-bit (4-hex) chunks
                # order: [15:0], [31:16], ..., [width-1:width-16]
                for i in range(len(tok), 0, -hex_per_chunk):
                    chunk_hex = tok[max(0, i - hex_per_chunk):i]
                    out.append(int(chunk_hex, 16))
    return out

def mask(n: int) -> int:
    """
    生成 n 位宽的掩码
    例如: n=32 -> 0xFFFFFFFF
    """
    return (1 << n) - 1


def sext(val: int, bits: int) -> int:
    """
    将整数 val 截断到 bits 位，并解释为有符号数
    返回 Python int（可能是负数）
    """
    val &= mask(bits)             # 截断到 bits 位
    sign = 1 << (bits - 1)        # 最高位符号位
    return (val ^ sign) - sign    # 符号扩展


def zext(val: int, bits: int) -> int:
    """
    将整数 val 截断到 bits 位，并解释为无符号数
    返回非负整数
    """
    return val & mask(bits)


def wrap(val: int, xlen: int) -> int:
    """
    将整数 val 截断到机器字长 xlen 位
    即结果保持在 [0, 2^xlen-1] 范围内
    """
    return val & mask(xlen)


def w_result(val: int) -> int:
    """
    用于 RV64 的 *W 类指令（ADDW, SUBW, MULW, DIVW 等）
    规则：取低 32 位运算结果 -> 符号扩展到 64 位
    """
    v32 = zext(val, 32)           # 取低 32 位
    return sext(v32, 32) & mask(64)


def mul_high(a: int, b: int, xlen: int, signed_a: bool, signed_b: bool) -> int:
    """
    计算乘法的高位结果 (MULH/MULHU/MULHSU)
    a, b: 输入操作数
    xlen: 机器字长 (32 或 64)
    signed_a/signed_b: 指定操作数是否带符号
    返回乘积的高 xlen 位
    """
    if signed_a:
        a = sext(a, xlen)
    else:
        a = zext(a, xlen)
    if signed_b:
        b = sext(b, xlen)
    else:
        b = zext(b, xlen)
    prod = a * b
    return (prod >> xlen) & mask(xlen)


def div_signed(a: int, b: int, xlen: int) -> int:
    """
    有符号除法 (DIV 指令)
    满足 RISC-V 规范：
    - 除零: 返回 -1
    - 溢出 (MIN / -1): 返回 MIN
    结果截断为 xlen 位
    """
    a_s = sext(a, xlen)
    b_s = sext(b, xlen)
    if b_s == 0:
        return mask(xlen)  # -1
    if a_s == -(1 << (xlen - 1)) and b_s == -1:
        return a_s & mask(xlen)
    q = int(a_s / b_s)  # Python / 是浮点除，结果转 int 等价于向零截断
    return wrap(q, xlen)


def rem_signed(a: int, b: int, xlen: int) -> int:
    """
    有符号取余 (REM 指令)
    满足 RISC-V 规范：
    - 除零: 结果 = 被除数
    - 溢出 (MIN / -1): 结果 = 0
    - 余数符号与被除数相同
    """
    a_s = sext(a, xlen)
    b_s = sext(b, xlen)
    if b_s == 0:
        return wrap(a_s, xlen)
    if a_s == -(1 << (xlen - 1)) and b_s == -1:
        return 0
    q = int(a_s / b_s)
    r = a_s - q * b_s
    return wrap(r, xlen)


def div_unsigned(a: int, b: int, xlen: int) -> int:
    """
    无符号除法 (DIVU 指令)
    除零: 返回全 1
    """
    a_u = zext(a, xlen)
    b_u = zext(b, xlen)
    if b_u == 0:
        return mask(xlen)
    return wrap(a_u // b_u, xlen)


def rem_unsigned(a: int, b: int, xlen: int) -> int:
    """
    无符号取余 (REMU 指令)
    除零: 返回被除数
    """
    a_u = zext(a, xlen)
    b_u = zext(b, xlen)
    if b_u == 0:
        return wrap(a_u, xlen)
    return wrap(a_u % b_u, xlen)
