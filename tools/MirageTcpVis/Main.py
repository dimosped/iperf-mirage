'''
Created on 22 Aug 2013

@author: dimos
'''
from TcpDumpProcessor import TcpDumpProcessor
import pylab as plot


def createPlot(pData, pLineLabels, pLineStyles, pPlotTitle, pXaxisLabel, pYaxisLabel, pAxisLimits=None, pWithGrid=False):
    if not type(pData) is list or len(pData) == 0 or \
         not type(pLineLabels) is list or len(pLineLabels) != len(pData)  or \
         not type(pLineStyles) is list or len(pLineStyles) != len(pData)  or \
         (not pAxisLimits is None) and (not type(pAxisLimits) is list or len(pAxisLimits) != 4):
        print "serverTest: createPlot: Mismatched or malformed plot data\n."
        return False
    for i, plotLine in enumerate(pData):
        print "-----------\n" + str(plotLine) + "\n-----------------------\n"
        plot.plot(plotLine[0], plotLine[1], label=pLineLabels[i], color=pLineStyles[i][0], linestyle=pLineStyles[i][1], linewidth=pLineStyles[i][2], marker=pLineStyles[i][3], mew=pLineStyles[i][4])
    plot.legend()
    plot.xlabel(pXaxisLabel, fontsize=14, color='red')
    plot.ylabel(pYaxisLabel, fontsize=14, color='red')
    plot.title(pPlotTitle)
    plot.grid(pWithGrid)
    if not pAxisLimits is None:
        plot.axis(pAxisLimits)
    #plt.text(60, .025, r'$\mu=100,\ \sigma=15$')
    plot.show()
    return True



def plotSenderTxRxData(pFileName, pTimeWindow=None):
    mDP = TcpDumpProcessor()
    mDP.loadDumpFromFile(pFileName)
#     mDP.printTimeSeries()
    #-----------------------------------------------
    #   TX-Segments and RX-Acks
    #-----------------------------------------------
    if pTimeWindow is None:
        sentSegs = mDP.filterTimeSeries(mDP.OP_TX, mDP.KIND_SEG)
        receivedAcks = mDP.filterTimeSeries(mDP.OP_RX, mDP.KIND_SEG)
    else:
        sentSegs = mDP.filterTimeSeries(mDP.OP_TX, mDP.KIND_SEG, pTimeWindow)
        receivedAcks = mDP.filterTimeSeries(mDP.OP_RX, mDP.KIND_SEG, pTimeWindow)
    sentSegs = mDP.generatePlotData(sentSegs, 0) # time VS transmitted segment_num which is the first item in the details field
    receivedAcks = mDP.generatePlotData(receivedAcks, 1) # time VS received ack_num which is the second item in the details field
    createPlot([sentSegs, receivedAcks],  
            ["SentSegments", "ReceivedAcks"], 
            [['k', '-', 2.0, '+', 3.0], ['r', '-', 2.0, '+', 3.0]], 
            "Sender TCP dump", 
            "Time (sec)", 
            "seqNum")


def plotSenderTxDelayData(pFileName, pTimeWindow=None):
    mDP = TcpDumpProcessor()
    mDP.loadDumpFromFile(pFileName)
#     mDP.printTimeSeries()
    #-----------------------------------------------
    #   TX Delay
    #-----------------------------------------------
    delayTX = mDP.filterTimeSeries(mDP.OP_TX, "*", pTimeWindow)
    delayTX = mDP.generatePlotData(delayTX)
    mDP.printMyTimeSeries(delayTX)
    createPlot([delayTX],  
            ["TX Delay"], 
            [['k', '-', 2.0, '+', 3.0]], 
            "My TCP dump", 
            "Time (sec)", 
            "# of Items")


def plotSenderCongestionWindow(pFileName, pTimeWindow=None):
    mDP = TcpDumpProcessor()
    mDP.loadDumpFromFile(pFileName)
#     mDP.printTimeSeries()
    #-----------------------------------------------
    #   TX Delay
    #-----------------------------------------------
    if pTimeWindow is None:
        winUpd = mDP.filterTimeSeries(mDP.OP_WND, mDP.KIND_UPD)
    else:
        winUpd = mDP.filterTimeSeries(mDP.OP_WND, mDP.KIND_UPD, pTimeWindow)
    cwnd = mDP.generatePlotData(winUpd, 7) # time VS congestion windows which is the 7th item in the details field, in window update records
    createPlot([cwnd],  
           ["Congestion Window"], 
           [['k', '-', 2.0, '+', 3.0]], 
           "My TCP dump", 
           "Time (sec)", 
           "Size (bytes)")



def plotReceiverRxTxData(pFileName, pTimeWindow=None):
    mDP = TcpDumpProcessor()
    mDP.loadDumpFromFile(pFileName)
#     mDP.printTimeSeries()
    #-----------------------------------------------
    #   RX-Segments and TX-Acks
    #-----------------------------------------------
    if pTimeWindow is None:
        receivedSegs = mDP.filterTimeSeries(mDP.OP_RX, mDP.KIND_SEG)
        sentAcks = mDP.filterTimeSeries(mDP.OP_TX, mDP.KIND_SEG)
    else:
        receivedSegs = mDP.filterTimeSeries(mDP.OP_RX, mDP.KIND_SEG, pTimeWindow)
        sentAcks = mDP.filterTimeSeries(mDP.OP_TX, mDP.KIND_SEG, pTimeWindow)
    receivedSegs = mDP.generatePlotData(receivedSegs, 0) # time VS received segment_num which is the first item in the details field
    sentAcks = mDP.generatePlotData(sentAcks, 1) # time VS sent ack_num which is the second item in the details field
    createPlot([receivedSegs, sentAcks],  
            ["ReceivedSegments", "SentAcks"], 
            [['k', '-', 2.0, '+', 3.0], ['r', '-', 2.0, '+', 3.0]], 
            "My TCP dump", 
            "Time (sec)", 
            "# of Items")



def plotReceiverTxDelayData(pFileName, pTimeWindow=None):
    mDP = TcpDumpProcessor()
    mDP.loadDumpFromFile(pFileName)
#     mDP.printTimeSeries()
    #-----------------------------------------------
    #   TX Delay
    #-----------------------------------------------
    if pTimeWindow is None:
        delayTX = mDP.filterTimeSeries(mDP.OP_TX, "*")
    else:
        delayTX = mDP.filterTimeSeries(mDP.OP_TX, "*", pTimeWindow)
    delayTX = mDP.generatePlotData(delayTX)
#     mDP.printMyTimeSeries(delayTX)
    createPlot([delayTX],  
            ["TX Delay"], 
            [['k', '-', 2.0, '+', 3.0]], 
            "My TCP dump", 
            "Time (sec)", 
            "# of Items")




if __name__ == '__main__':
    plotSenderTxRxData("./data/sender.log")
#     plotSenderTxDelayData("./data/sender.log")
#     plotReceiverRxTxData("./data/receiver.log", ["*", 0.1])
#     plotReceiverTxDelayData("./data/receiver.log", ["*", 0.1])
#     plotSenderCongestionWindow("./data/sender.log")




#----------------------------------
#   Usage Examples
#----------------------------------    
#     mDP = TcpDumpProcessor()
#     mDP.loadDumpFromFile("./data/clientDump.txt")
#     filteredData = mDP.filterTimeSeries("*", "*")
#     filteredData = mDP.filterTimeSeries("*", "*", ["*", "*"])
#     filteredData = mDP.filterTimeSeries(mDP.OP_TX, "*")
#     filteredData = mDP.filterTimeSeries("*", mDP.KIND_ACK)
#     filteredData = mDP.filterTimeSeries(mDP.OP_RX, mDP.KIND_ACK)
#     filteredData = mDP.filterTimeSeries(mDP.OP_RX, mDP.KIND_SEG)
#     filteredData = mDP.filterTimeSeries(mDP.OP_WND, mDP.KIND_UPD)
#     filteredData = mDP.filterTimeSeries(mDP.OP_TX, mDP.KIND_SEG, [0.001, "*"])
#     filteredData = mDP.filterTimeSeries(mDP.OP_TX, mDP.KIND_SEG, ["*", 0.001])
#     filteredData = mDP.filterTimeSeries(mDP.OP_TX, mDP.KIND_SEG, [0.001, 0.003])
#     mDP.printMyTimeSeries(filteredData)
#-----------------------------------------------
#   TX-Segments and RX-Acks
#-----------------------------------------------
#     sentSegs = mDP.filterTimeSeries(mDP.OP_TX, mDP.KIND_SEG)
#     sentSegs = mDP.generatePlotData(sentSegs, 0)
#      
#     receivedAcks = mDP.filterTimeSeries(mDP.OP_RX, mDP.KIND_ACK)
#     receivedAcks = mDP.generatePlotData(receivedAcks, 0)
#     
#     createPlot([sentSegs, receivedAcks],  
#             ["SentSegments", "ReceivedAcks"], 
#             [['k', '-', 2.0, '+', 3.0], ['r', '-', 2.0, '+', 3.0]], 
#             "My TCP dump", 
#             "Time (sec)", 
#             "# of Items")
#-----------------------------------------------
#   Congestion Window
#-----------------------------------------------
# winUpd = mDP.filterTimeSeries(mDP.OP_WND, mDP.KIND_UPD)
# cwnd = mDP.generatePlotData(winUpd, 7)
# createPlot([cwnd],  
#            ["Congestion Window"], 
#            [['k', '-', 2.0, '+', 3.0]], 
#            "My TCP dump", 
#            "Time (sec)", 
#            "Size (bytes)")