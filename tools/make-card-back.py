# Bakes the back of the cards held in hand: a circuit grid on navy with one acid node. Upload it with
# tools/upload-group-assets.py and put the id in src/shared/CardCore/CardArt.luau.
#
#   python tools/make-card-back.py
import os

import cv2
import numpy as np
S=4; W,H=150*S,240*S
navy=(79,50,41); bone=(223,230,232); acid=(11,254,194)
def mix(a,b,t): return tuple(int(a[i]+(b[i]-a[i])*t) for i in range(3))
img=np.full((H,W,3),navy,np.uint8)
m=8*S; cell=11*S
# grid area
x0,y0,x1,y1=m+5*S,m+5*S,W-m-5*S,H-m-5*S
nx=round((x1-x0)/cell); ny=round((y1-y0)/cell)
cx=(x1-x0)/nx; cy=(y1-y0)/ny
line=mix(navy,bone,0.28)
for i in range(nx+1):
    x=int(x0+i*cx); cv2.line(img,(x,y0),(x,y1),line,S//2,cv2.LINE_AA)
for j in range(ny+1):
    y=int(y0+j*cy); cv2.line(img,(x0,y),(x1,y),line,S//2,cv2.LINE_AA)
for i in range(nx+1):
    for j in range(ny+1):
        cv2.circle(img,(int(x0+i*cx),int(y0+j*cy)),int(1.3*S),bone,-1,cv2.LINE_AA)
# centre node
c=(W//2,H//2); r=int(cy*1.5)
cv2.rectangle(img,(int(c[0]-cx*1.5),int(c[1]-cy*1.5)),(int(c[0]+cx*1.5),int(c[1]+cy*1.5)),navy,-1)
cv2.rectangle(img,(int(c[0]-cx*1.5),int(c[1]-cy*1.5)),(int(c[0]+cx*1.5),int(c[1]+cy*1.5)),acid,S,cv2.LINE_AA)
d=int(cx*0.75)
cv2.fillPoly(img,[np.array([(c[0],c[1]-d),(c[0]+d,c[1]),(c[0],c[1]+d),(c[0]-d,c[1])])],acid,cv2.LINE_AA)
# border
cv2.rectangle(img,(m,m),(W-m,H-m),bone,int(1.5*S),cv2.LINE_AA)
# clear corners, the same size as the card art's (tools/make-card-art.py)
r=10*S
mask=np.zeros((H,W),np.uint8)
cv2.rectangle(mask,(r,0),(W-1-r,H-1),255,-1)
cv2.rectangle(mask,(0,r),(W-1,H-1-r),255,-1)
for x,y in ((r,r),(W-1-r,r),(r,H-1-r),(W-1-r,H-1-r)):
    cv2.circle(mask,(x,y),r,255,-1,cv2.LINE_AA)
img=np.dstack([img,mask])
os.makedirs("assets/cards", exist_ok=True)
cv2.imwrite("assets/cards/hand_back.png", img)
