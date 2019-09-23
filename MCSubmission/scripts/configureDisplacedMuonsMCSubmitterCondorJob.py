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
from optparse import OptionParser
#from CMSDataTools.AnalysisTree.TranslateStringBetweenPythonAndShell import *


class BatchManager:
   def __init__(self):
      # define options and arguments ====================================
      self.parser = OptionParser()

      self.parser.add_option("--batchqueue", type="string", help="Batch queue")
      self.parser.add_option("--batchscript", type="string", help="Name of the HTCondor executable")
      self.parser.add_option("--tarfile", type="string", help="Name of the tar file to upload")
      self.parser.add_option("--outdir", type="string", help="Name of the job output directory")
      self.parser.add_option("--condorsite", type="string", help="Name of the HTCondor site")
      self.parser.add_option("--condoroutdir", type="string", help="Name of the HTCondor output directory")
      self.parser.add_option("--outlog", type="string", help="Name of the output log file")
      self.parser.add_option("--errlog", type="string", help="Name of the output error file")

      self.parser.add_option("--nevents", type="int", help="Number of events")
      self.parser.add_option("--seed", type="int", help="Seed")

      self.parser.add_option("--dry", dest="dryRun", action="store_true", default=False, help="Do not submit jobs, just set up the files")
      self.parser.add_option("--interactive", dest="interactive", action="store_true", default=False, help="Do not submit jobs; run them interactively")


      (self.opt,self.args) = self.parser.parse_args()

      optchecks=[
         "batchqueue",
         "batchscript",
         "tarfile",
         "outdir",
         "condorsite",
         "condoroutdir",
         "outlog",
         "errlog",
         "nevents",
         "seed"
      ]
      for theOpt in optchecks:
         if not hasattr(self.opt, theOpt) or getattr(self.opt, theOpt) is None:
            sys.exit("Need to set --{} option".format(theOpt))

      # Get abolute path
      self.opt.outdir = os.path.abspath(self.opt.outdir)

      if self.opt.nevents <= 0:
         sys.exit("Number of requested events ({}) is not positive. Exiting...".format(self.opt.nevents))
      if self.opt.seed <= 0:
         sys.exit("Seed {} is not positive. Exiting...".format(self.opt.nseed))

      if not os.path.isfile(self.opt.batchscript):
         print "Batch executable does not exist in current directory, will search for CMSSW_BASE/bin"
         if os.path.isfile(os.getenv("CMSSW_BASE")+"/bin/"+os.getenv("SCRAM_ARCH")+"/"+self.opt.batchscript):
            self.opt.batchscript = os.getenv("CMSSW_BASE")+"/bin/"+os.getenv("SCRAM_ARCH")+"/"+self.opt.batchscript
            print "\t- Found the batch executable"
         else:
            sys.exit("Batch executable {} does not exist. Exiting...".format(self.opt.batchscript))

      for theOpt in optchecks:
         print "Option {}={}".format(theOpt,getattr(self.opt, theOpt))


      self.submitJobs()


   def produceCondorScript(self):
      currentdir = os.getcwd()
      currentCMSSWBASESRC = os.getenv("CMSSW_BASE")+"/src/" # Need the trailing '/'
      currendir_noCMSSWsrc = currentdir.replace(currentCMSSWBASESRC,'')
      #if self.opt.command is not None:
      #   self.opt.command = translateFromPythonToShell(self.opt.command)

      scramver = os.getenv("SCRAM_ARCH")
      singularityver = "cms:rhel6"
      if "slc7" in scramver:
         singularityver = "cms:rhel7"

      condorscriptargs = {
         "home" : os.path.expanduser("~"),
         "uid" : os.getuid(),
         "batchScript" : self.opt.batchscript,
         "CONDORSITE" : self.opt.condorsite,
         "CONDOROUTDIR" : self.opt.condoroutdir,
         "outDir" : self.opt.outdir,
         "outLog" : self.opt.outlog,
         "errLog" : self.opt.errlog,
         "QUEUE" : self.opt.batchqueue,
         "SINGULARITYVERSION" : singularityver,
         "TARFILE" : self.opt.tarfile,
         "NEVENTS" : self.opt.nevents,
         "SEED" : self.opt.seed
      }

      condorscriptcontents = """
universe={QUEUE}
+DESIRED_Sites="T2_US_UCSD,T2_US_Caltech,T3_US_UCR,T2_US_MIT,T2_US_Vanderbilt,T2_US_Wisconsin,T3_US_Baylor,T3_US_Colorado,T3_US_NotreDame,T3_US_Rice,T3_US_Rutgers,T3_US_UMD,T3_US_Vanderbilt_EC2,T3_US_OSU"
executable              = {batchScript}
arguments               = {TARFILE} {NEVENTS} {SEED} {CONDORSITE} {CONDOROUTDIR}
Initialdir              = {outDir}
output                  = {outLog}.$(ClusterId).$(ProcId).txt
error                   = {errLog}.$(ClusterId).$(ProcId).err
log                     = $(ClusterId).$(ProcId).log
request_memory          = 4000M
+JobFlavour             = "tomorrow"
x509userproxy           = {home}/x509up_u{uid}
#https://www-auth.cs.wisc.edu/lists/htcondor-users/2010-September/msg00009.shtml
periodic_remove         = JobStatus == 5
transfer_executable=True
transfer_input_files    = {TARFILE}
transfer_output_files = ""
+Owner = undefined
+project_Name = "cmssurfandturf"
notification=Never
should_transfer_files = YES
when_to_transfer_output = ON_EXIT_OR_EVICT
Requirements = ((HAS_SINGULARITY=?=True) && (HAS_CVMFS_cms_cern_ch =?= true)) || (regexp("(uaf-[0-9]{{1,2}}|uafino)\.", TARGET.Machine) && !(TARGET.SlotID>(TotalSlots<14 ? 3:7) && regexp("uaf-[0-9]", TARGET.machine)))
+SingularityImage = "/cvmfs/singularity.opensciencegrid.org/bbockelm/{SINGULARITYVERSION}"

queue

"""
      condorscriptcontents = condorscriptcontents.format(**condorscriptargs)

      self.condorScriptName = "condor.sub"
      condorScriptFile = open(self.opt.outdir+"/"+self.condorScriptName,'w')
      condorScriptFile.write(condorscriptcontents)
      condorScriptFile.close()


   def submitJobs(self):
      self.produceCondorScript()

      jobcmd = "cd {}; condor_submit {}; cd -".format(self.opt.outdir, self.condorScriptName)
      if self.opt.dryRun:
         jobcmd = "echo Job command: '" + jobcmd + "'"
      ret = os.system( jobcmd )



if __name__ == '__main__':
   batchManager = BatchManager()
