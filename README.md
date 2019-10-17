# autoGrading_sakaiND
Repository for scripts that assist with grading files from Sakai for Notre Dame TAs

## assesmentGrading_sakai.sh
A script designed to assist with grading the exercises. It takes as input the xls file for an assessment downloaded from sakai, as well as the "export.csv" file downloaded from online photo for your section. 

Using the student IDs from the csv file for your section, the script writes a separate file for the student responses of each question. It also gives you the option to view the responses for a question, then add scores and comments for each student response.

To run the script, enter into the terminal "scriptName.sh studentList.csv studentResponses.xls". For example, "assessmentGrading_sakai.sh export.csv Assessment-Exercise_03-09262019.xls".

It may be necessary to download "xls2csv" before running the script, since the assessment responses are downloaded as an xls file from sakai. To install xls2csv I believe you need to enter "sudo apt-get install xls2csv" (https://linux.die.net/man/1/xls2csv).

It may also be necessary to perform "sudo apt-get update" first, before installing "xls2csv" using "sudo apt-get install xls2csv".
