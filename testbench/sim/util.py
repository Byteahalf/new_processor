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