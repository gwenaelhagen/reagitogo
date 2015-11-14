#!/bin/bash

#todo: print errors

repository_owner=$1 #gwenaelhagen
repository=$2 #submodules-playground
sha1_ref=$3 #develop
log_file="$repository_owner-$repository.log"

#submodule="submodule2"
#json="{   
#    \"path\": \"submodule1\", 
#    \"mode\": \"test1\",
#    \"sha1\": \"adasdfsfd1\"
#}
#{   
#    \"path\": \"submodule2\", 
#    \"mode\": \"test2\",
#    \"sha1\": \"adasdfsfd2\"
#}"
#regex="(\{\s*\"path\":\s*\"$submodule\",\s*[^}]+\})"
#    
#    sm=$(echo $json | grep -Pzo "(?s)$regex")
#    echo $sm
#    regex="\"sha1\":\s*\"\K.+?(?=\")"
#    sha1=$(echo $sm | grep -Pzo "(?s)$regex")
#    echo $sha1
#    exit
    
#Without the need to install the grep variant pcregrep, you can do multiline search with grep.
#
#$ grep -Pzo "(?s)^(\s*)\N*main.*?{.*?^\1}" *.c
#Explanation:
#
#-P activate perl-regexp for grep (a powerful extension of regular extensions)
#
#-z suppress newline at the end of line, subtituting it for null character. That is, grep knows where end of line is, but sees the input as one big line.
#
#-o print only matching. Because we're using -z, the whole file is like a single big line, so if there is a match, the entire file would be printed; this way it won't do that.
#
#In regexp:
#
#(?s) activate PCRE_DOTALL, which means that . finds any character or newline
#
#\N find anything except newline, even with PCRE_DOTALL activated
#
#.*? find . in nongreedy mode, that is, stops as soon as possible.
#
#^ find start of line
#
#\1 backreference to first group (\s*) This is a try to find same indentation of method
#
#As you can imagine, this search prints the main method in a C (*.c) source file.

function archive_url {
    local reference=$1
    echo https://github.com/$repository_owner/$repository/archive/$reference.zip
}

function archive_filename {
    local reference=$1
    echo $repository_owner-$repository-$reference.zip
}

function download_archive {
    local archive_url=$1
    local archive_file=$2
    
    curl -L -o $archive_file $archive_url #>>$log_file 2>&1 
    
    echo $archive_file
}

function unzip_archive {
    local archive_file=$1
    local destination_folder=$2
    
    unzip $archive_file -d $destination_folder #>>$log_file 2>&1
    
    #remove root folder
    root_folder=$(ls $destination_folder | sort -n | head -1)
    mv $destination_folder/$root_folder/* $destination_folder #>>$log_file 2>&1
    #todo: how to do for other files without names?
    mv $destination_folder/$root_folder/.gitmodules $destination_folder #>>$log_file 2>&1
    rm -rf $destination_folder/$root_folder #>>$log_file 2>&1
    
    echo $destination_folder
}

function delete_archive {
    local archive_file=$1
    
    rm $archive_file #>>$log_file 2>&1
}

function submodules {
    local repository_folder=$1
    
    #less $repository_folder/.gitmodules
    
    #todo
    echo "submodule1,../submodule1.git" #;submodule2,../submodule2.git" 
}

function tree_base_url {
    #todo echo https://api.github.com/repos/$repository_owner/$repository
    echo https://api.github.com/repos/$repository_owner #todo: https://api.github.com/repos
}

function tree {
    local repository_url=$1
    local reference=$2
    
    #todo: test for absolute url
    #todo: temp line
    repository_url=${repository_url:2}
    
    #remove .git
    if [ "${repository_url:${#repository_url}-4}" = ".git" ]
        then
            repository_url=${repository_url::${#repository_url}-4}
    fi
    
    url="$(tree_base_url)$repository_url"
    
    #echo $url/git/trees/$reference
    
    curl $url/git/trees/$reference
}

function submodule_sha1 {
    local json=$1
    local submodule_name=$2
    
    #echo "SUBMODULE1"
    #echo $submodule_name
    #echo "JSON"
    #echo $json
    
    local regex="(\{\s*\"path\":\s*\"$submodule_name\",\s*[^}]+\})"
    
    local submodule=$(echo $json | grep -Pzo "(?s)$regex")
    
    #echo "SUBMODULE"
    #echo $submodule

    regex="\"sha\":\s*\"\K.+?(?=\")"
    
    local sha1=$(echo $submodule | grep -Pzo "(?s)$regex")
    
    echo $sha1
}

archive_file=$(download_archive $(archive_url $sha1_ref) $(archive_filename $sha1_ref))
archive_folder=${archive_file::${#archive_file}-4} #remove .zip

archive_folder=$(unzip_archive $archive_file $archive_folder)
delete_archive $archive_file

IFS=';' read -r -a submodules_array <<< $(submodules $archive_folder)

json=$(tree "../$repository" $sha1_ref) #todo: temp "../"

for submodule in ${submodules_array[@]}
do
    IFS=',' read -r -a submodule_properties <<< "$submodule"
    path=${submodule_properties[0]}
    url=${submodule_properties[1]}
    
    sha1=$(submodule_sha1 "$json" "$path") # "" for $json since multi lines string
    
    echo $url
    echo $sha1
done

#todo recursivity
