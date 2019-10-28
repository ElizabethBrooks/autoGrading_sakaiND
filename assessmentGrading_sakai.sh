#!/bin/bash
#Usage: scriptName.sh studentList.csv studentResponses.xls
#Ex usage: assessmentGrading_sakai.sh export.csv Assessment-Exercise_03-09262019.xls
#Retrieve file names from input
studentList=$1 #Section from online photo student list
studentResponses=$2 #Assignment responses from Sakai xls download
studentCount=0 #Number of students in the input section
assesmentTag="_${studentResponses:0:${#studentResponses}-4}" #Assesment name without file extension
#Clean up
assesmentTag=$( echo $assesmentTag | sed 's/-/_/g' )
#Convert the xls file of student responses to csv
#using a ; delimiter since there are , in the header fields
xls2csv -c ";" $studentResponses > tmpResponseFile.csv
#Cleanup and preprocess assesment response file
sed -i ':a;N;$!ba;s/"\n"/NEWROW/g' tmpResponseFile.csv
sed -i ':a;N;$!ba;s/\n/NEWLINE/g' tmpResponseFile.csv
sed -i 's/NEWROW/"\n"/g' tmpResponseFile.csv
#Determine number of questions in the input assignment
numQuestions=$( head -n1 tmpResponseFile.csv | grep -o "Part 1, Question " | wc -l )
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
#Make sure tmp response file does not already exsist
if [ -f "tmpSectionResponses.csv" ]; then #File already exsists
	rm "tmpSectionResponses.csv"
fi
#Loop through student IDs for final clean up
while IFS=" " read -r studentID; do
	idEntry=$( echo $studentID | tr -d '\r,[:cntrl:]' )
	IDARRAY[studentCount]="$idEntry"
	grep -iF "$idEntry" tmpResponseFile.csv >> tmpSectionResponses.csv
	let studentCount+=1
done < tmpStudentList.txt
#Ask the user for grading preference
#Option 1: store the responses in separate txt files and exit
#Option 2: view responses, grade, comment, and store in separate txt files
read -p "Would you like to view and grade student responses? (y/n) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
	gradingPreference=1
else
	gradingPreference=2
fi
#Separate out student responses that have no submission
nonSubmissions=unSubmitted$assesmentTag.csv
#Make sure file does not already exsist
if [ -f "$nonSubmissions" ]; then #File already exsists
	rm "$nonSubmissions"
fi
grep -iF "No submission" tmpSectionResponses.csv > $nonSubmissions
#Clean up
sed 's/"//g' $nonSubmissions > tmpNonSubmissions.csv
cut -d ';' -f 3,4 tmpNonSubmissions.csv > $nonSubmissions
#Retrieve student responses for each question, and store in separate txt files
#Student responses begin with the ninth column, and continue for every other column
questionNum=0
while [ $(( $questionNum*2 )) -lt $numQuestions ]; do
	questionDisplacement=$(( 9+$questionNum*2 ))
	questionFile=question$(( $questionNum+1 ))$assesmentTag.csv
	#Make sure file does not already exsist
	if [ -f "$questionFile" ]; then #File already exsists
		rm "$questionFile"
	fi
	cut -d ';' -f 3,$questionDisplacement tmpSectionResponses.csv > $questionFile
	#Clean up
	if [ $gradingPreference -eq 2 ]; then
		#Clean up
		sed -i 's/NEWLINE/\n/g' $questionFile
	fi
	#Increment question number
	let questionNum+=1
done
#Allow the review of responses and entry of scores,
#if the preference for grading was selected
if [ $gradingPreference -eq 1 ]; then
	#Loop through section question response files
	questionFileNum=1
	fileFlag=1
	while [ $questionFileNum -le $questionNum ]; do
		scoredQuestions=scoredQuestion$(( $questionFileNum ))$assesmentTag.csv
		questionFile=question$(( $questionFileNum ))$assesmentTag.csv
		#Make sure file does not already exsist
		if [ -f "$scoredQuestions" ]; then #File already exsists
			#Determine if user would like to continue with RE-SCORING responses
			echo "~"
			read -p "Would you like to RE-SCORE responses for question $questionFileNum? (y/n) " -n 1 -r
			echo
			if [[ $REPLY =~ ^[Yy]$ ]]; then
				rm "$scoredQuestions"
				scoringPreference=1
			else
				scoringPreference=2
			fi
		else #File does not already exsist
			#Determine if user would like to continue with scoring un-scored responses
			echo "~"
			read -p "Would you like to score responses for question $questionFileNum? (y/n) " -n 1 -r
			echo
			if [[ $REPLY =~ ^[Yy]$ ]]; then
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
				grep -iF "$currentStudent" $questionFile | sed 's/NEWLINE/\n/g' >> $scoredQuestions
				grep -iF "$currentStudent" $questionFile | sed 's/NEWLINE/\n/g'
				#Accept score input and write to files
				read -p "Score: " scoreEntry
				echo ";Score: $scoreEntry" >> $scoredQuestions
				#Accept comment input and write to file
				read -p "Comments (Press enter when finished): " commentEntry
				echo ";Comments: $commentEntry" >> $scoredQuestions
				#Output response separator to file and stdin
				echo "~" >> $scoredQuestions
				echo "~"
				#Increment student ID
				let studentNum+=1
			done
			#clean up
			rm "$questionFile"
		else
			#Clean up
			sed -i 's/NEWLINE/\n/g' $questionFile
		fi
		#Increment question file
		let questionFileNum+=1
	done
	#Create file with all scores
	if [ $gradingPreference -eq 1 ]; then
		#Add cleaned scores to file array
		questionFileNum=1
		for scoredFile in scoredQuestion*.csv; do
			#Temporary score file names
			tmpScoreFile=tmp"$scoredFile"
			tmpScoreFileCleaned=tmpC"$scoredFile"
			#Retrieve scores for current question
			grep -iF "Score:" $scoredFile > $tmpScoreFile
			cut -d ';' -f 2 $tmpScoreFile > $tmpScoreFileCleaned
			sed -i "s/Score: //g" $tmpScoreFileCleaned
			#Add current question tag to header
			SCOREFILE+="Q$questionFileNum "
			#Add current question scores file to array
			SCOREFILES+="$tmpScoreFileCleaned "
			#clean up
			rm "$tmpScoreFile"
			#Increment question file
			let questionFileNum+=1
		done
		#Insert student IDs
		printf "%s\n" "${IDARRAY[@]}" > tmpStudentIDList.csv
		#Merge score files
		paste -d ';' tmpStudentIDList.csv ${SCOREFILES[@]} > allScores$assesmentTag.csv
		#Clean up
		sed -i 's/;/; /g' allScores$assesmentTag.csv
		rm "tmpStudentIDList.csv"
		for tmpScoreFile in ${SCOREFILES[@]}; do
			rm "$tmpScoreFile"
		done
	fi
fi
#Clean up
rm "tmpNonSubmissions.csv"
rm "tmpSectionResponses.csv"
rm "tmpResponseFile.csv"
rm "tmpStudentList.txt"