#!/bin/bash
#Usage: scriptName.sh studentList.csv studentResponses.xls
#Ex usage: sakaiGrading.sh export.csv Assessment-Exercise_03-09262019.xls
#Retrieve file names from input
studentList=$1 #Section from online photo student list
studentResponses=$2 #Assignment responses from Sakai xls download
studentCount=0 #Number of students in the input section
#Convert the xls file of student responses to csv
#using a ; delimiter since there are , in the header fields
xls2csv -c ";" $studentResponses > tmpResponseFile.csv
#Determine number of questions in the input assignment
numQuestions=$( head -n1 tmpResponseFile.csv | grep -o "Part 1, Question " | wc -l )
#Ask the user for grading preference
#Option 1: store the responses in separate txt files and exit
#Option 2: view responses, grade, comment, and store in separate txt files
read -p "Would you like to view and grade student responses? (y/n) " -r
echo #Create new line for next prompt
if [[ $REPLY =~ ^[Yy]$ ]]; then
	gradingPreference=1
else
	gradingPreference=2
fi
#Compare student list from online photo to assignment responses
#and retrieve responses from students that match the online photo list
#The third column of the student responses contains the student IDs
#The first of ten columns of the student list contains the student IDs
#First, clean up and preprocess input student list csv file
sed 's/, BIOS ..... Sec 01 CRN: ...../\n/g' $studentList > tmpStudentList.txt
sed -i 's/, Info/\n/g' tmpStudentList.txt
sed -i 's/","",//g' tmpStudentList.txt
sed -i 's/,"/:/g' tmpStudentList.txt
sed -i 's/:.*nd.edu//g' tmpStudentList.txt
sed -i '1,2d' tmpStudentList.txt
while IFS=" " read -r studentID; do
	idEntry=$( echo $studentID | tr -d '\r,[:cntrl:]' )
	IDARRAY[studentCount]="$idEntry"
	grep -iF "$idEntry" tmpResponseFile.csv >> tmpSectionResponses.csv
	let studentCount+=1
done < tmpStudentList.txt
echo $studentCount
#Separate out student responses that have no submission
nonSubmissions=unSubmitted_"${studentResponses:0:${#studentResponses}-4}".csv
grep -iF "No submission" tmpSectionResponses.csv > unSubmitted_"${studentResponses:0:${#studentResponses}-4}".csv
#Clean up
sed -i 's/"//g' $nonSubmissions
cut -d ';' -f 3,4 $nonSubmissions > $nonSubmissions
#Retrieve student responses for each question, and store in separate txt files
#Student responses begin with the ninth column, and continue for every other column
questionNum=0
while [ $(( $questionNum*2 )) -lt $numQuestions ]; do
	echo "Writing Question $(( $questionNum+1 )) to txt file..."
	questionDisplacement=$(( 9+$questionNum*2 ))
	questionFile=question$(( $questionNum+1 ))"_${studentResponses:0:${#studentResponses}-4}".csv
	cut -d ';' -f 3,$questionDisplacement tmpSectionResponses.csv > $questionFile
	#Clean up
	sed -i 's/\n//g' $questionFile
	#Increment question number
	let questionNum+=1
done
#Allow the review of responses and entry of scores,
#if the preference for grading was selected
if [ $gradingPreference -eq 1 ]; then
	#Loop through section question response files
	questionFileNum=1
	while [ $questionFileNum -le $questionNum ]; do
		scoredQuestions=scoredQuestion$(( $questionFileNum ))"_${studentResponses:0:${#studentResponses}-4}".csv
		questionFile=question$(( $questionFileNum ))"_${studentResponses:0:${#studentResponses}-4}".csv
		#Check if the current scoring file already exists
		if [ ! -f $scoredQuestions ]; then #Does not exsist
			#Determine if user would like to continue with scoring un-scored responses
			read -p "Would you like to score responses for question $questionFileNum? (y/n) " -r
			echo #Create new line for next prompt
			if [[ $REPLY =~ ^[Yy]$ ]]; then
				scoringPreference=1
			else
				scoringPreference=2
			fi
		else #Already exsists
			#Determine if user would like to continue with re-scoring exsisting file of responses
			read -p "Would you like to re-score already exsisting file of scored responses for question $questionFileNum? (y/n) " -r
			echo #Create new line for next prompt
			if [[ $REPLY =~ ^[Yy]$ ]]; then
				rm $scoredQuestions
				scoringPreference=1
			else
				scoringPreference=2
			fi
		fi
		#Continue if user selected to continue with scoring or re-scoring
		if [ $scoringPreference -eq 1 ]; then
			#Loop through all student responses and allow scoring and commenting
			studentNum=1
			while [ $studentNum -le $studentCount ]; do
				#Identify current student response and display
				currentStudent=${IDARRAY[$studentNum-1]}
				grep -iF "$currentStudent" $questionFile >> $scoredQuestions
				grep -iF "$currentStudent" $questionFile
				#Accept score input and write to file
				read -p "Score: " scoreEntry
				echo ";Score: $scoreEntry" >> $scoredQuestions
				#Accept comment input and write to file
				read -p "Comments (Press enter when finished commenting): " commentEntry
				echo ";Comments: $commentEntry" >> $scoredQuestions
				#Increment student ID
				let studentNum+=1
			done
			#clean up
			rm $questionFile
		fi
		#Increment question file
		let questionFileNum+=1
	done
fi
#Clean up
rm tmpSectionResponses.csv
rm tmpResponseFile.csv
rm tmpStudentList.txt