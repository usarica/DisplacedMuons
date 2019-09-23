#!/bin/env python

import sys
import imp
import copy
import os
import filecmp
import shutil
import pickle
import math
import pprint
import subprocess
from datetime import date
from argparse import ArgumentParser as OptionParser
from CMSDataTools.AnalysisTree.TranslateStringBetweenPythonAndShell import *


class BatchManager:
   def __init__(self):
      # define options and arguments ====================================
      self.parser = OptionParser()

      self.parser.add_argument("--input", type=str, help="File containing input commands")
      self.parser.add_argument("--output", type=str, help="Output file with the list of commands")
      self.parser.add_argument("--add_range", type=str, action="append", help="Wildcards to replace")


      self.opt = self.parser.parse_args()

      optchecks=[
         "input",
         "output",
         "add_range"
      ]
      for theOpt in optchecks:
         if not hasattr(self.opt, theOpt) or getattr(self.opt, theOpt) is None:
            sys.exit("Need to set --{} option".format(theOpt))

      if not os.path.isfile(self.opt.input):
         sys.exit("List {} does not exist. Exiting...".format(self.opt.input))

      self.rangelist = {}
      for rng in self.opt.add_range:
         rnglist = rng.split(':')
         if len(rnglist)!=2:
            raise RuntimeError("{} could not be split properly.".format(rng))
         rnglist[0] = rnglist[0].replace('<','')
         rnglist[0] = rnglist[0].replace('>','')
         rnglist[1] = rnglist[1].split(',')
         if len(rnglist[1])==2:
            rnglist[1][0]=int(rnglist[1][0])
            rnglist[1][1]=int(rnglist[1][1])+1
         elif len(rnglist[1])==1:
            rnglist[1][0]=str(rnglist[1][0])
         elif len(rnglist[1])>2:
            raise RuntimeError("{} could not be split properly.".format(rnglist[1]))
         self.rangelist[rnglist[0]]=rnglist[1]


      self.run()


   def run(self):
      currentdir = os.getcwd()
      finput = open(self.opt.input,'r')
      foutput = open(self.opt.output, 'w')

      for fline in finput:
         fline = fline.lstrip()
         if fline.startswith('#'):
            continue
         fline = " ".join(fline.split()); fline += '\n'
         wlinelist = [ fline ] # Start with a single line
         for key,val in self.rangelist.iteritems():
            wlinelisttmp = []
            for tmpline in wlinelist:
               if key in tmpline:
                  if len(val)==1:
                     addline=tmpline.replace('<'+key+'>',val[0])
                     wlinelisttmp.append(addline)
                  else: # Length==2
                     for ival in range(val[0],val[1]):
                        addline=tmpline.replace('<'+key+'>',str(ival))
                        wlinelisttmp.append(addline)
            wlinelist = wlinelisttmp
         for wline in wlinelist:
            foutput.write(wline)


      foutput.close()
      finput.close()



if __name__ == '__main__':
   batchManager = BatchManager()
