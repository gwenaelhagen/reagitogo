#!/bin/bash

#todo: username/pwd

#todo: print errors

repository_url=$1
sha1_ref=$2 #develop
zip_result=$3
username=$4
password=$5
cur_dir=$(pwd)

#todo: check params and print use
#todo: handle modules not in root folder
#todo: respect all rules in submodules function
#todo: handle spaces in path, handle './' too
#todo: handle git@ submodules

function repository_base_url {
    local repository_url=$1
    
    local regex="^\Khttp[s]{0,1}:\/\/github\.com\/(?=.*)"
    echo $(echo $repository_url | grep -Pzo "(?s)$regex")
}

function repository_owner {
    local repository_url=$1
    
    local regex="^http[s]{0,1}:\/\/[^\/]+\/\K[^\/]+(?=.*)"
    echo $(echo $repository_url | grep -Pzo "(?s)$regex")
}

function repository_name {
    local repository_url=$1

    local regex="^http[s]{0,1}:\/\/[^\/]+\/[^\/]+\/\K[^\/]+(?=.*)"
    echo $(echo $repository_url | grep -Pzo "(?s)$regex")
}

function archive_url {
    local repository_url=$1
    local reference=$2
    
    echo $repository_url/archive/$reference.zip
}

function download_archive {
    local archive_url=$1
    local archive_file=$2
    
    if [ "$username" != "" ]
        then
            curl -u "$username:$password" -L -o $archive_file $archive_url #>>$log_file 2>&1
    else
        curl -L -o $archive_file $archive_url #>>$log_file 2>&1
    fi
    
    echo $archive_file
}

function unzip_archive {
    local archive_file=$1
    local destination_folder=$2
    
    unzip $archive_file -d $destination_folder >>$log_file 2>&1
    
    #remove root folder
    root_folder=$(ls $destination_folder | sort -n | head -1)
    mv $destination_folder/$root_folder/* $destination_folder >>$log_file 2>&1
    #todo: how to do for other files without names?
    mv $destination_folder/$root_folder/.gitmodules $destination_folder >>$log_file 2>&1
    rm -rf $destination_folder/$root_folder >>$log_file 2>&1
    
    echo $destination_folder
}

function delete_file {
    local archive_file=$1
    
    rm $archive_file #>>$log_file 2>&1
}

function submodules {
    local repository_folder=$1
    
    #based on https://git-scm.com/docs/gitmodules as it was on 11/18/2015
    #important things from this url:
    #The file contains one subsection per submodule, and the subsection value is the name of the submodule. The name is set to the path where the submodule has been added unless it was customized with the --name option of git submodule add. Each submodule section also contains the following required keys:
    #submodule.<name>.path
    #Defines the path, relative to the top-level directory of the Git working tree, where the submodule is expected to be checked out. The path name must not end with a /. All submodule paths must be unique within the .gitmodules file.
    #submodule.<name>.url
    #Defines a URL from which the submodule repository can be cloned. This may be either an absolute URL ready to be passed to git-clone[1] or (if it begins with ./ or ../) a location relative to the superproject’s origin repository.
    #Example:
    #[submodule "libfoo"]
    #    path = include/foo
    #    url = git://foo.com/git/lib.git
    #see https://git-scm.com/docs/git-config#_syntax also
    #CAUTION:
    #A line that defines a value can be continued to the next line by ending it with a \; the backquote and the end-of-line are stripped. Leading whitespaces after name =, the remainder of the line after the first comment character # or ;, and trailing whitespaces of the line are discarded unless they are enclosed in double quotes. Internal whitespaces within the value are retained verbatim.
    #Inside double quotes, double quote " and backslash \ characters must be escaped: use \" for " and \\ for \.
    #The following escape sequences (beside \" and \\) are recognized: \n for newline character (NL), \t for horizontal tabulation (HT, TAB) and \b for backspace (BS). Other char escape sequences (including octal escape sequences) are invalid.
    
    #todo: improve regex
    local empty_line_regex="^\s*\K.*(?=\s*)"
    local comment_line_regex="^\s*\K#(?=.*)"
    local section_line_regex="^\s*\K\[(?=.*)"
    local commented_submodule_regex="^\s*#[^\[]*\[\s*\Ksubmodule(?=[^\]]+\].*)"
    local key_value_line_regex="^\s*\K[^=]+=\s*[^\s]+(?=\s*)"
    local key_regex="^\s*\K[^\s=]+(?=.*)"
    local value_regex="^\s*[^=\s]+\s*+=\s*\K.+?(?=\\s)"
    local submodule_regex="^\s*\[\s*\Ksubmodule(?=.*)"
    
    local match=""
    local skip_section=true
    local key=""
    local value=""
    
    local path=""
    local url=""
    
    local result=""
    
    while IFS='' read -r line || [[ -n "$line" ]]; do
        match=$(echo $line | grep -Pzo "(?s)$empty_line_regex")
        #skip empty lines
        if [ "$match" = "" ]
            then
                continue
        fi
        match=$(echo $line | grep -Pzo "(?s)$commented_submodule_regex")
        #skip commented sections
        if [ "$match" = "#" ]
            then
                skip_section=true
                continue
        fi
        match=$(echo $line | grep -Pzo "(?s)$comment_line_regex")
        #skip comment lines
        if [ "$match" = "#" ]
            then
                continue
        fi
        match=$(echo $line | grep -Pzo "(?s)$section_line_regex")
        #new submodule
        if [ "$match" = "[" ]
            then
                if [ "$path" != "" ]
                    then
                        if [ "$url" != "" ]
                            then
                                result="$result$path|$url;"
                        fi
                fi
                
                path=""
                url=""
                
                match=$(echo $line | grep -Pzo "(?s)$submodule_regex")
                if [ "$match" != "submodule" ]
                    then
                        skip_section=true
                        continue
                fi

                skip_section=false
                continue
        fi
        match=$(echo $line | grep -Pzo "(?s)$key_value_line_regex")
        #key value lines
        if [ "$match" != "" ]
            then
                if [ skip_section = true ]
                    then
                        continue
                fi
                key=$(echo $line | grep -Pzo "(?s)$key_regex")
                value=$(echo $line | grep -Pzo "(?s)$value_regex")

                if [ "$key" = "path" ]
                    then
                        path=$value
                fi
                if [ "$key" = "url" ]
                    then
                        url=$value
                fi
            continue
        fi

    done <"$repository_folder/.gitmodules"
    
    if [ "$path" != "" ]
        then
            if [ "$url" != "" ]
                then
                    result="$result$path|$url;"
            fi
    fi
    
    echo $result
}

function tree {
    local repository_url=$1 # doesn't end with '.git'
    local reference=$2
    
    local api_url=""
    
    local github_url=$(repository_base_url $repository_url) #https://github.com
    local repository_owner=$(repository_owner $repository_url) #gwenaelhagen
    local repository=$(repository_name $repository_url) #submodules-playground
    
    if [ "$github_url" != "" ] #not http(s)
        then
            api_url="https://api.github.com/repos/"
    fi
    
    #todo: entreprise url

    local url=$api_url$repository_owner/$repository

    if [ "$username" != "" ]
        then
            curl -u "$username:$password" $url/git/trees/$reference
    else
        curl $url/git/trees/$reference
    fi
}

function submodule_sha1 {
    local json=$1
    local submodule_name=$2
    
    local regex="(\{\s*\"path\":\s*\"$submodule_name\",\s*[^}]+\})"
    
    local submodule=$(echo $json | grep -Pzo "(?s)$regex")

    regex="\"sha\":\s*\"\K.+?(?=\")"
    
    local sha1=$(echo $submodule | grep -Pzo "(?s)$regex")
    
    echo $sha1
}

function handle_repository {
    local repository_url=$1
    local reference=$2
    local archive_filename=$3
    local parent_repository_url=$4
    
    #remove .git
    if [ "${repository_url:${#repository_url}-4}" = ".git" ]
        then
            repository_url=${repository_url::${#repository_url}-4}
    fi
    
    #http(s)
    local regex="^\Khttp[s]{0,1}:\/\/(?=.+)"
    local http=$(echo $repository_url | grep -Pzo "(?s)$regex")
    
    if [ "$http" == "" ] #not http(s)
        then
            repository_url=${repository_url:3}
            local parent_repository_base_url=$(echo $parent_repository_url | grep -Pzo "(?s)^\Khttp[s]{0,1}:\/\/.+\/(?=[^\/]+)")
            repository_url=$parent_repository_base_url$repository_url
    fi

    local archive_file=$(download_archive $(archive_url $repository_url $reference) $archive_filename)
    
    local archive_folder=${archive_file::${#archive_file}-4} #remove .zip

    archive_folder=$(unzip_archive $archive_file $archive_folder)
    delete_file $archive_file
    
    IFS=';' read -r -a submodules_array <<< $(submodules "$archive_folder")

    local json=$(tree $repository_url $reference)
    
    if [ "$main_folder" == "" ]
        then
            main_folder="$archive_folder"
    fi
    
    cd "$archive_folder"

    for submodule in ${submodules_array[@]}
    do
        IFS='|' read -r -a submodule_properties <<< "$submodule"
        path=${submodule_properties[0]}
        url=${submodule_properties[1]}
        
        sha1=$(submodule_sha1 "$json" "$path") # "" for $json since multi lines string
        
        if [ "$url" != "" ]
            then
                if [ "$sha1" != "" ]
                    then
                    handle_repository $url $sha1 "$path.zip" $repository_url
                fi
        fi
    done
}

repository_owner=$(repository_owner $repository_url) #gwenaelhagen
repository=$(repository_name $repository_url) #submodules-playground

log_file="$cur_dir/$repository_owner-$repository.log"

main_folder=""

archive_name=$repository_owner-$repository-$sha1_ref.zip

handle_repository $repository_url $sha1_ref $archive_name

cd $cur_dir
cd $main_folder

#todo: delete git files (.git*)

cd $cur_dir

if [ "$zip_result" == "1" ]
    then
        cd $cur_dir
        zip -r $archive_name $main_folder >>$log_file 2>&1
        #rm -rf $main_folder >>$log_file 2>&1
fi
