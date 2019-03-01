import numpy as np
import math

import flood as fl

### Input flood probability csv file
flood_prob_100 = []
with open('100yearSF.csv','r') as f:
	for line in f.readlines():
		flood_prob_100.append(list(map(float,line.split(','))))
	f.close()

flood_prob_10 = []
with open('10yearSF.csv','r') as f:
	for line in f.readlines():
		flood_prob_10.append(list(map(float,line.split(','))))
	f.close()

one_story = [0.000,0.007,0.008,0.024,0.052,0.090,0.138,0.194,0.255,0.320,0.387,0.455,0.522,0.586,0.645,0.698,0.742,0.777,0.801,0.811,0.811,0.811,0.811,0.811,0.811] 		


print("=====================")
# Input paramter
dis_gov = 0.025
dis_res = 0.12

calLength = 99 # Need to mininus 1 since python index from 0

# Mean NY:422460 SF:822200



self_move = 0
motivated_move = 0
for i in one_story:
	movCost = 0.6*822200
	loss = 822200*i
	self_move = fl.runModel(flood_prob_100[0],calLength,loss,dis_gov,dis_res,movCost)[0][0]
	motivated_move = fl.runModel(flood_prob_100[0],calLength,loss,dis_gov,dis_res,movCost)[0][1]
	print(self_move,motivated_move)
