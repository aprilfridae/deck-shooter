"""Gives an exported arm clip a new pose count, blending between its poses.

Run: python tools/resample_clip.py <clip file> <clip name> <poses> <fps> [hit frame] [new hit frame]
Run it again after re-exporting a clip from Blender.
"""
import math
import re
import sys

NUMBER = r"-?\d+(?:\.\d+)?(?:e-?\d+)?"


def blend_line(a, b, share):
    numbers_a = [float(n) for n in re.findall(NUMBER, a[a.index("{" if "{" in a else "("):])]
    numbers_b = [float(n) for n in re.findall(NUMBER, b[b.index("{" if "{" in b else "("):])]
    if numbers_a == numbers_b:
        return a
    assert len(numbers_a) == 7, a
    dot = sum(x * y for x, y in zip(numbers_a[3:], numbers_b[3:]))
    sign = -1 if dot < 0 else 1  # a quaternion and its negative are the same turn
    place = [x + (y - x) * share for x, y in zip(numbers_a[:3], numbers_b[:3])]
    turn = [x + (y * sign - x) * share for x, y in zip(numbers_a[3:], numbers_b[3:])]
    length = math.sqrt(sum(x * x for x in turn))
    values = ", ".join(f"{x:.4f}" for x in place + [x / length for x in turn])
    return a[: a.index("{" if "{" in a else "(") + 1] + (" " + values + " }," if "{" in a else values + "),")


def blend(a, b, share):
    lines_a, lines_b = a.split("\n"), b.split("\n")
    assert len(lines_a) == len(lines_b)
    out = []
    for x, y in zip(lines_a, lines_b):
        out.append(blend_line(x, y, share) if ("= {" in x and "bones" not in x) or "CFrame.new" in x else x)
    return "\n".join(out)


def main():
    path, name, count, fps = sys.argv[1], sys.argv[2], int(sys.argv[3]), sys.argv[4]
    text = open(path, encoding="utf8", newline="").read()
    start = text.index(f"\t{name} = {{\n")
    open_frames = text.index("\t\tframes = {\n", start) + len("\t\tframes = {\n")
    close_frames = text.index("\t\t},\n\t},\n", open_frames)
    frames = re.findall(r"\t\t\t\{\n.*?\n\t\t\t\},\n", text[open_frames:close_frames], re.S)
    last = len(frames) - 1
    if len(sys.argv) > 6:  # keeps the hit pose exact, and moves it to a new frame
        hit, target = int(sys.argv[5]), int(sys.argv[6])
        # One steady windup all the way to the top, then the whip pose and the hit.
        spots = [(i / (target - 2)) ** 2 * (hit - 2) for i in range(target - 1)] + [hit - 1]
        spots += [hit + (i / (count - target - 1)) ** 1.5 * (last - hit) for i in range(count - target)]  # lingers on the hit
    else:
        spots = [i * last / (count - 1) for i in range(count)]
    made = []
    for at in spots:
        low = min(int(at), len(frames) - 2)
        made.append(blend(frames[low], frames[low + 1], at - low))
    header = re.sub(r"fps = [\d.]+", f"fps = {fps}", text[start:open_frames], count=1)
    text = text[:start] + header + "".join(made) + text[close_frames:]
    open(path, "w", encoding="utf8", newline="").write(text)


if __name__ == "__main__":
    main()
