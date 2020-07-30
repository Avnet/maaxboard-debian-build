import os

BasePath="deb_%d=deb/imxgstplugin/MM_04.04.05_1902_L4.14.98_GA/%s"
SearchPath="H:/Work/scrpit/test_rootfs/deb/imxgstplugin/MM_04.04.05_1902_L4.14.98_GA"
index=36
def loadDebs():
    global index
    for root, dirs, files in os.walk(SearchPath):        
        for f in files:
            if f.endswith(".deb"):
                print(BasePath%(index,f))
                index += 1;


if __name__ == "__main__":
    loadDebs()