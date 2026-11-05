import sys
gun = sys.argv[sys.argv.index("--") + 1]
p_ = r"H:\rblxgame\tools\export_arm_clips.py"
ns = {"GUN": gun}
exec(compile(open(p_, encoding='utf8').read(), p_, 'exec'), ns)
print("EXPORTED", gun, ns.get("result"))
