using PyPlot, JLD

data = JLD.load("./182602_15-52_sdpScalingTest.jld")
resCost = data["resCost"]
resIter = data["resIter"]
resDim = data["resDim"]

resDim = map(x->Int(x),resDim)
cc =  ["#1f77b4" "#ff7f0e" "#2ca02c" "#d62728" "#9467bd" "#8c564b"]

PyPlot.figure(4,facecolor="white",figsize=(12,5))
PyPlot.xticks(fontsize=15)
PyPlot.yticks(fontsize=15)
PyPlot.plot(1:1:nn,resIter[1:nn,1],label=L"\rho=1.0 (off)","--",color=cc[1])
PyPlot.plot(1:1:nn,resIter[1:nn,2],label=L"\rho=1.0 (on)",color=cc[1])
PyPlot.plot(1:1:nn,resIter[1:nn,3],label=L"\rho=100.0 (off)","--",color=cc[2])
PyPlot.plot(1:1:nn,resIter[1:nn,4],label=L"\rho=100.0 (on)",color=cc[2])
PyPlot.plot(1:1:nn,resIter[1:nn,5],label=L"\rho=1000.0 (off)","--",color=cc[3])
PyPlot.plot(1:1:nn,resIter[1:nn,6],label=L"\rho=1000.0 (on)",color=cc[3])
PyPlot.grid(true)
PyPlot.xticks(1:1:nn,resDim,fontsize=10)
PyPlot.xlabel("Matrix dimension",fontsize=15)
PyPlot.ylabel("Iterations to Convergence",fontsize=15)
PyPlot.legend(ncol = 6,bbox_to_anchor=(0., 1.02, 1., .102),loc=3)

PyPlot.savefig("/Users/Micha/Dropbox/Research/OSSDP/Notes/Scaling_experiments/figs/sdp_rho.eps")