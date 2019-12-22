#! /usr/local/bin/python3.8

import ruamel.yaml
import os
import argparse
import sys


# Usage Help
#yaml2tfvars.py --buildfile xyz.yaml ==> Build for configuration (nothing but preparing the directory structure and terraform variable files)

parser = argparse.ArgumentParser(description='This is a aws account validator script.')
parser.add_argument('--buildfile', help='Build configuration for the given yaml file')
parser.add_argument('--load',help='Load the Yaml file')

# Check if the given directory is already exist in the given path, if it is not exist create it.
def createDirectory(path, name):
    try:
        if(os.path.exists(path)):
            pass
        else:
            os.mkdir(path)
            #print ("Successfully created the directory %s " % name)
    except OSError:
        print ("Creation of the directory %s failed" % name)

# Return the count of elements in the list
def getElementCount(element):
    count = 0
    if isinstance(element, list):
        count += len(element)
    return count

# Create a new file and write the config text in it.
def createNewFile(file_path):
    file_object = open(file_path, 'w+')
    return file_object

# Create aws profile file.
def createAwsProfile(fp, region_name, resource_name, tfvars):
    fp.write('PROVIDER_NAME=AWS\n')
    fp.write('REGION_NAME=' + region_name + '\n')
    fp.write('PROJECT_NAME=Symphony\n')
    fp.write('CLIENT_NAME=AHS\n')
    fp.write('SERVICE_NAME=Storage\n')
    fp.write('RESOURCE_NAME=' + resource_name + '\n\n')
    fp.write('export TERRAFORM_BASE=/SecOps/Terraform\n')
    fp.write('export WORK_DIR=$TERRAFORM_BASE/work\n')
    fp.write('export PROJECT_WORK_DIR=$WORK_DIR/$PROJECT_NAME\n')
    fp.write('export CLIENT_WORK_DIR=$PROJECT_WORK_DIR/$CLIENT_NAME\n')
    fp.write('export PROVIDER_WORK_DIR=$CLIENT_WORK_DIR/$PROVIDER_NAME\n')
    fp.write('export AWS_REGION_DIR=$PROVIDER_WORK_DIR/' + region_name + '\n')
    fp.write('export AWS_SERVICE_DIR=$AWS_REGION_DIR/$SERVICE_NAME\n')
    fp.write('export RESOURCE_PATH=$AWS_SERVICE_DIR/' + resource_name + '\n\n')
    fp.write('export CONF_FILE=$RESOURCE_PATH/deploy.conf\n')
    fp.write('export TFVARS_FILE=$RESOURCE_PATH/' + tfvars + '\n\n')
    fp.write('echo $TERRAFORM_BASE\n')
    fp.write('echo $WORK_DIR\n')
    fp.write('echo $PROJECT_WORK_DIR\n')
    fp.write('echo $CLIENT_WORK_DIR\n')
    fp.write('echo $PROVIDER_WORK_DIR\n')
    fp.write('echo $AWS_REGION_DIR\n')
    fp.write('echo $AWS_SERVICE_DIR\n')
    fp.write('echo $RESOURCE_PATH\n')
    fp.close()

# Create Build for configuration.
def createBuildFile(file_path):
    # Load the yaml file data into dictionary
    aws_accounts = ruamel.yaml.round_trip_load(open(file_path), preserve_quotes=True)
    try:
        baseDirPath = os.environ["WORKSPACE"]
        #baseDirPath = 'E:\Muthu'
    except KeyError:
        print("Please set the environment variable WORKSPACE")
        sys.exit(1)
    workName = "work"
    workPath = baseDirPath + '/' + workName
    createDirectory(workPath, workName)
    region_count = getElementCount(aws_accounts['Region'])
    buildCount = 0
    for i in range(region_count):
        regionName = aws_accounts['Region'][i]['Name']
        regionPath = workPath + '/' + regionName
        createDirectory(regionPath, regionName)
        s3count = getElementCount(aws_accounts['Region'][i]['S3tfstate'])
        for j in range(s3count):
            s3Name = aws_accounts['Region'][i]['S3tfstate'][j]['Name']
            s3Path = regionPath + '/' + s3Name
            s3ConfigPath = s3Path + '/' + "s3.tfvars"
            s3AwsProfilePath = s3Path + '/' + "aws_profile"
            if(aws_accounts['Region'][i]['S3tfstate'][j]['Deploy'] == True):
                try:
                    createDirectory(s3Path, s3Name)
                    fileObject1 = createNewFile(s3ConfigPath)
                    fileObject1.write('region_name = "' + regionName + '"\n')
                    fileObject1.write('s3_name = "' + s3Name + '"\n')
                    #fileObject1.write('vpc_cidr = "' + str(aws_accounts['Region'][i]['S3tfstate'][j]['CIDR']) + '"\n\n')
                    fileObject1.write('tag_name = "' + s3Name + '"\n')
                    fileObject1.write('tag_project = "Symphony"\n')
                    fileObject1.write('tag_organization = "Advantasure Inc."\n')
                    fileObject1.write('tag_clietn = "AHS"\n\n')
                    fileObject1.write('tfstate_backend = "' + 'symphony-ahs-backend-tfstate-' + regionName + '"\n')
                    fileObject1.write('tfstate_path = "' + 'tfstate/Networking/' + s3Name + '/s3.tfvars' + '"\n')       
                    fileObject1.close()
                    fileObject2 = createNewFile(s3AwsProfilePath)
                    createAwsProfile(fileObject2, regionName, s3Name, os.path.basename(s3ConfigPath))
                    print("INFO: Generating S3: " + s3Name + " configuration ... Done")
                    print(s3ConfigPath)
                    buildCount += 1
                except:
                    print("ERROR: Generating S3: " + s3Name + " configuration ... Failed")
                aws_accounts['Region'][i]['S3tfstate'][j]['Deploy'] = False
    if(buildCount == 0):
        print('Build configurations are in "false" status')
    return aws_accounts

#Update the Build flag in the Original Yaml file
def updateYamlFile(aws_updated, file_path):
    with open(file_path, 'w') as yaml_file:
        ruamel.yaml.round_trip_dump(aws_updated, yaml_file)

# Execution starts from here.
def main():
    args = parser.parse_args()
    #print(args)
    if(args.buildfile):
        #Build for configuration (Preparing the directory structure and terraform variable files)
        file = args.buildfile
        try:
            aws_updated = createBuildFile(file)
            updateYamlFile(aws_updated, file)
            #print("Build for Configuration (Preparing the directory structure and terraform variable files) Successfully Completed")
        except IOError as e:
            print("I/O error({0}): {1}".format(e.errno, e.strerror))
        except:
            print("Unexpected error:", sys.exc_info()[0])
    elif(args.load):
        file = open(args.load, "r")
        if file.mode == "r":
            contents = file.read()
            print(contents)
    else:
        print("Please give the proper input parameter")
        parser.print_usage()
        print()

if __name__== "__main__":
    main()
