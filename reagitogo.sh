#!/bin/bash

#todo: print errors

repository_owner=$1 #gwenaelhagen
repository=$2 #submodules-playground
sha1_ref=$3 #develop
log_file="$repository_owner-$repository.log"

username=$4
password=$5

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
    
    curl -u "$username:$password" -L -o $archive_file $archive_url >>$log_file 2>&1 
    
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

function delete_archive {
    local archive_file=$1
    
    rm $archive_file >>$log_file 2>&1
}

function submodules {
    local repository_folder=$1
    
    #less $repository_folder/.gitmodules
    
    #todo
    echo "submodule1,../submodule1.git;submodule2,../submodule2.git" 
}

function tree_base_url {
    #todo echo https://api.github.com/repos/$repository_owner/$repository
    echo https://api.github.com/repos/$repository_owner
}

function tree {
    local repository_url=$1
    local reference=$2
    
    #todo: test for absolute url
    #todo: temp line
    repository_url=${repository_url:2}
    
    #remove .git
    repository_url=${repository_url::${#repository_url}-4}
    
    url="$(tree_base_url)$repository_url"
    
    curl -u "$username:$password" $url/git/trees/$reference
}

archive_file=$(download_archive $(archive_url $sha1_ref) $(archive_filename $sha1_ref))
archive_folder=${archive_file::${#archive_file}-4} #remove .zip

archive_folder=$(unzip_archive $archive_file $archive_folder)
delete_archive $archive_file

#todo parse the result to get 665b9b7567eaf2773179598968e1861c746c207c
tree "../submodules-playground" $sha1_ref

IFS=';' read -r -a submodules_array <<< $(submodules $archive_folder)

for submodule in ${submodules_array[@]}
do
    IFS=',' read -r -a submodule_properties <<< "$submodule"
    path=${submodule_properties[0]}
    url=${submodule_properties[1]}
    
    tree $url "665b9b7567eaf2773179598968e1861c746c207c" #todo
done

#todo recursivity
