'''
Created on 22 Aug 2013

@author: dimos
'''

import re

class TcpDumpProcessor(object):
    '''
    classdocs
    '''
    
    timeSeries = None
    OP_FIELD = "Op"
    KIND_FIELD = "Kind"
    TIME_FIELD = "Time"
    DELAY_FIELD = "Delay"
    DETAILS_FIELD = "details"
    OP_RX = "RX"
    OP_TX = "TX"
    OP_WND = "WND"
    KIND_UPD = "UPD"
    KIND_ACK = "ACK"
    KIND_SEG = "SEG"
    MIN_LINE_LENGTH = 40
    NUM_FIELDS = 5
    FIELD_SEPARATOR = ","

    def __init__(self):
        '''
        Constructor
        '''
        self.dataStore = {}
        self.timeSeries = []
        
    
    def updateRecordFromTag(self, tags, pRec):
        if tags[0] == self.TIME_FIELD: # Is a Time field
            try:
                pRec[0] = float(tags[1])
            except ValueError:
                print "TcpDumpProcessor: updateRecordFromTag: Bad Time value %s \n" % tags[1]
                return False
        elif tags[0] == self.DELAY_FIELD: # Is a Delay field
            try:
                pRec[1] = float(tags[1])
            except ValueError:
                print "TcpDumpProcessor: updateRecordFromTag: Bad Delay value %s \n" % tags[1]
                return False
        elif tags[0] == self.OP_FIELD: # Is an Operation field
            if tags[1] == self.OP_RX:
                pRec[2] = self.OP_RX
            elif tags[1] == self.OP_TX:
                pRec[2] = self.OP_TX
            elif tags[1] == self.OP_WND:
                pRec[2] = self.OP_WND
            else:
                print "TcpDumpProcessor: updateRecordFromTag: Malformed Operation field value %s \n" % tags[1]
                return False
        elif tags[0] == self.KIND_FIELD: # is a Kind field
            if tags[1] == self.KIND_ACK:
                pRec[3] = self.KIND_ACK
            elif tags[1] == self.KIND_SEG:
                pRec[3] = self.KIND_SEG
            elif tags[1] == self.KIND_UPD:
                pRec[3] = self.KIND_UPD
            else:
                print "TcpDumpProcessor: updateRecordFromTag: Malformed Operation field value %s \n" % tags[1]
                return False
        elif tags[0] == self.DETAILS_FIELD: # is a Details field
            data = tags[1].replace("[", "")
            data = data.replace("]", "")
            values = data.split(" ")
            try:
                pRec[4] = map(int, values)
            except ValueError:
                print "TcpDumpProcessor: updateRecordFromTag: Bad value(s) in the details field %s \n" % tags[1]
                print values
                return False
            if len(pRec[4]) < 1:
                print "TcpDumpProcessor: updateRecordFromTag: Too few values in the details field %s \n" % tags[1]
                return False
        else:
            print "TcpDumpProcessor: updateRecordFromTag: Unrecognised field  %s \n" % tags[0]
            return False
        return True
        
    def loadDumpFromFile(self, pFilename):
        if (not type(pFilename) is str) and len(pFilename) == 0:
            return False
        content = None
        try:
            with open(pFilename, "r") as f:
                content = f.read()
        except IOError as err:
            print "TcpDumpProcessor: loadDumpFromFile: IO Error for file %s: \n%s" % (pFilename, str(err))
            return False
        return self.loadRawData(content)
    
    def checkLineFields(self, pLine):
        isUnique = True
        allFields = [ self.KIND_FIELD, self.TIME_FIELD, self.DELAY_FIELD, self.DETAILS_FIELD]
        for field in allFields:
            isUnique &= len( [m.start() for m in re.finditer(field, pLine)] ) == 1
        return isUnique
    
    def loadRawData(self, pRawData):
        if (not type(pRawData) is str) or (len(pRawData) < self.MIN_LINE_LENGTH ):
            print "TcpDumpProcessor: loadDumpFromFile: Malformed data \n"
            return False
        lines = pRawData.split("\n")
        for line in lines:
            line = line.strip()
            if len(line) < self.MIN_LINE_LENGTH:
                if len(line) > 1:
                    print "TcpDumpProcessor: loadDumpFromFile: Bad line format, too short: \n %s \n" % line
            else:
                newRec = [-1 for x in range(self.NUM_FIELDS)]
                doSkipLine = False
                if self.checkLineFields(line):
                    fields = line.split(self.FIELD_SEPARATOR)
                    if len(fields) == self.NUM_FIELDS:
                        for field in fields:
                            if not doSkipLine:
                                tags = field.split("=")
                            if len(tags) != 2:
                                print "TcpDumpProcessor: loadDumpFromFile: : Field (%s) is malformed in line: \n %s \n %s \n" % (field, line)
                            else:
                                tags[0] = tags[0].strip()
                                tags[1] = tags[1].strip()
                                doSkipLine = not self.updateRecordFromTag(tags, newRec)
                        if doSkipLine:
                            print "TcpDumpProcessor: loadDumpFromFile: Skipping bad line: \n %s \n" % line
                        else:
                            self.timeSeries.append(newRec)
                    else:
                        print "TcpDumpProcessor: loadDumpFromFile: Bad line format, too few fields: \n %s \n" % line
                else:
                    print "TcpDumpProcessor: loadDumpFromFile: Bad line format, no valid fields found or duplicate field occurrences were detected, skipping...: \n %s \n" % line
        if len(self.timeSeries) < 1:
            return False
        return True
    
    def filterTimeSeries(self, pOp, pKind, pTimeWin=None):
        if ( ((pOp != self.OP_RX) and (pOp != self.OP_TX) and (pOp != self.OP_WND) and (pOp != "*")) or\
             ((pKind != self.KIND_SEG) and (pKind != self.KIND_ACK) and (pKind != self.KIND_UPD) and (pKind != "*")) or\
             ((not pTimeWin is None) and (len(pTimeWin) != 2)) or\
             ((not pTimeWin is None) and (pTimeWin[0] != "*") and (pTimeWin[0] != "*") and (pTimeWin[1] <= pTimeWin[0]))
           ):
            print "TcpDumpProcessor: filterTimeSeries: Provided invalid arguments"
            return None
        retList = []
        for record in self.timeSeries:
            discard = False
            if not pTimeWin is None:
                discard = self.__filterTime(record[0], pTimeWin[0], pTimeWin[1])
            if (not discard) and (not pOp == "*"):
                discard = not (record[2] == pOp)
            if (not discard) and (not pKind == "*"):
                discard = not (record[3] == pKind)
            if not discard:
                retList.append(record)
        if len(retList) == 0:
            return None
        return retList
    
    def generatePlotData(self, pTimeSeries, pOffset=None):
        if pTimeSeries is None or len(pTimeSeries) == 0 or ((not pOffset is None) and pOffset < 0):
            print "TcpDumpProcessor: generatePlotData: The provided List is None"
            return None
        xData = [row[0] for row in pTimeSeries]
        yData = []
        if pOffset is None: # We want the Delay
            yData = [row[1] for row in pTimeSeries]
        else:
            for row in pTimeSeries:
                if pOffset >= len(row[4]):
                    print "TcpDumpProcessor: generatePlotData: Skipping row that doesn't match the offset (%d): \n %s" % (pOffset, str(row))
                else:
                    yData.append(row[4][pOffset])
            if len(yData) == 0:
                return None
        return [xData, yData]
                        
    def __filterTime(self, pT, pTimeStart, pTimeEnd):
        discard = False
        if pTimeStart != "*":
            if pT < pTimeStart:
                discard = True
        if not discard and pTimeEnd != "*":
            if pT > pTimeEnd:
                discard = True
        return discard
    
    def __printListNewLine(self, pList):
        if pList is None:
            print "TcpDumpProcessor: __printListNewLine: List is None"
            return None
        for record in pList:
            print record
            
    def getRXTimeSeries(self):
        return self.filterTimeSeries(self.OP_RX, "*")
    
    def getTXTimeSeries(self):
        return self.filterTimeSeries(self.OP_TX, "*")
    
    def getWNDTimeSeries(self):
        return self.filterTimeSeries(self.OP_WND, "*")
        
    def printTimeSeries(self):
        self.__printListNewLine(self.timeSeries)
        
    def printMyTimeSeries(self, pTeseries):
        self.__printListNewLine(pTeseries)
        
    
        