# DisplacedMuons/MCSubmission: Package for submitting MC for displaced muon studies

## Step 1: Prepare inputs

- Make an lst file (e.g. test.lst) with entries like

```
year=<YEAR> nevents=<NEVENTS> seed=<SEED> mcname=GluGluTo0PHH125ToZprimeZprimeTo2Mu2X_CTauVprime_50mm condorsite=t2.ucsd.edu condoroutdir=/hadoop/cms/store/user/usarica/DisplacedMuons/<YEAR>/GluGluTo0PHH125ToZprimeZprimeTo2Mu2X_CTauVprime_50mm
```

- Run createDisplacedMuonsMCSubmissionFile.py in order to create the job lines, e.g.

```
createDisplacedMuonsMCSubmissionFile.py --input=test.lst --output=test.txt --add_range="NEVENTS:500" --add_range="SEED:1230001,1230500" --add_range="YEAR:2018"
```

## Step 2: Job preparation and submission

- Create the condor submission directory and scripts for the jobs for submission, e.g.

```
submitDisplacedMuonsMCToCondor.sh infile=test.txt fragdir=configs/2018_gridpack gridpackdir=gridpacks/2018/GluGluTo0PHH125ToZprimeZprimeTo2Mu2X_CTauVprime_50mm outdir=./output date=190922
```

- Submit the jobs, e.g.

```
resubmitDisplacedMuonsMCSubmitterProduction.sh output/190922/
```
