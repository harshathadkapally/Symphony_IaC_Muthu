#!/usr/local/bin/python3

import ruamel.yaml
from string import Template
import os
import argparse
import sys

# Usage Help
#yaml2tfvars.py --buildfile xyz.yaml --templatefile xyz.TEMPLATE ==> Build for configuration (nothing but preparing the directory structure and terraform variable files)

parser = argparse.ArgumentParser(description='This is a aws account validator script.')
parser.add_argument('--yamlfile', help='Build configuration for the given yaml file')
parser.add_argument('--templatefile', help='Template file creation for the given template file')
parser.add_argument('--outputfolder', help='Destination folder for the given template file')
parser.add_argument('--load',help='Load the Yaml file')

# Return the count of elements in the list
def getElementCount(element):
    count = 0
    if isinstance(element, list):
        count += len(element) 
    return count  
# Check if the given directory is already exist in the given path, if it is not exist create it.
def createDirectory(path):
    try:
        if(os.path.exists(path)):
            pass
        else:
            os.mkdir(path)
    except OSError:
        print ("Creation of the directory %s failed" % path)
def createBuildFile(yaml_file, templatefiles, output_folder):
    #yaml_file = "Symphony_AHS_AWS_Network_Network.yaml"
    aws_accounts = ruamel.yaml.round_trip_load(open(yaml_file), preserve_quotes=True)
    count = getElementCount(aws_accounts['Region'])
    #templatefiles = ['aws_EC2tfstate.tfvars.TEMPLATE']
    output_template_path = ""
    #output_folder = "tmp"
    filenamewithoutext = os.path.basename(yaml_file).split(".")[0]
    filenamearr = filenamewithoutext.split("_")
    project = filenamearr[0]
    client = filenamearr[1]
    provider = filenamearr[2]
    service = filenamearr[3]
    resource_type = filenamearr[4]
    createDirectory(output_folder)
    reg_keys = {}
    buildCount = 0
    for i in range(count):
        regionName = aws_accounts['Region'][i]['Name']
        regionPath = output_folder + '/' + regionName
        createDirectory(regionPath) 
        service_path = regionPath + '/' + service
        createDirectory(service_path)
        resource_type_path = service_path +  '/' + resource_type
        createDirectory(resource_type_path)
        for reg_elm in aws_accounts['Region'][i]:
            if(reg_elm.lower() != "EC2"):
                region_keys = "\'REGION_"+reg_elm.upper()+"\':\'"+ str(aws_accounts['Region'][i][reg_elm])+"\',"
                reg_keys["REGION_"+reg_elm.upper()] =  str(aws_accounts['Region'][i][reg_elm])
        count = getElementCount(aws_accounts['Region'][i]['EC2'])
    		# EC2 node trace
        for j in range(count):
            ec2_keys ={}
            ec2Name = str(aws_accounts['Region'][i]['EC2'][j]['Name'])
            ec2Name = ec2Name.replace("{Region.Name}", regionName)
            ec2_dirPath = resource_type_path +"/"+ ec2Name
            if(str(aws_accounts['Region'][i]['EC2'][j]['Deploy']).casefold() == str(True).casefold() and str(aws_accounts['Region'][i]['EC2'][j]['Terraform']).lower() == "Deploy".lower()):
                try:
                    buildCount += 1
                    createDirectory(ec2_dirPath)
                    for ec2_elem in aws_accounts['Region'][i]['EC2'][j]:
                        if(ec2_elem.lower() != "subnet"):
                            #ec2_keys1 = '\"EC2_'+ec2_elem.upper()+"\":\""+ str(aws_accounts['Region'][i]['EC2'][j][ec2_elem])+"\","
                            ec2_keys["EC2_"+ec2_elem.upper()] =  str(aws_accounts['Region'][i]['EC2'][j][ec2_elem])
                    ec2_filenames = []
                    for tmp_file in templatefiles:
                        with open(tmp_file, "rt") as fin:
                            src = fin.read()
                            src = Template(src).safe_substitute(ec2_keys)
                            src = Template(src).safe_substitute(reg_keys)
                            output_template_path = os.path.splitext(os.path.basename(tmp_file))[0]
                            ec2_template_path = ec2_dirPath +"/"+ output_template_path
                            #print("filename EC2==",ec2_template_path)
                            with open(ec2_template_path, "wt") as fout:
                                fout.write(src)
                            fout.close()
                            ec2_filenames.append(ec2_template_path)
                        fin.close()
                    print("\nINFO: Generating EC2: " + ec2Name + " configuration ... Done")
                    for filename in ec2_filenames:
                        print(filename)
                except:
                    print("ERROR: Generating EC2: " + ec2Name + " configuration ... Failed")
                aws_accounts['Region'][i]['EC2'][j]['Deploy'] = False
    					#tfvar
            else:
                createDirectory(ec2_dirPath)
                for ec2_elem in aws_accounts['Region'][i]['EC2'][j]:
                    if(ec2_elem.lower().strip() == "name"):
                        ec2_keys["EC2_"+ec2_elem.upper()] =  str(aws_accounts['Region'][i]['EC2'][j][ec2_elem])            
    if(buildCount == 0):
        print('INFO:Build configurations are in "false" status')
    return aws_accounts
#Update the Build flag in the Original Yaml file
def updateYamlFile(aws_updated, file_path):
    with open(file_path, 'w') as yaml_file:
        ruamel.yaml.round_trip_dump(aws_updated, yaml_file)

# Execution starts from here.
def main():
    args = parser.parse_args()
    if(args.yamlfile and args.templatefile):
        #Build for configuration (Preparing the directory structure and terraform variable files) 
        buildfile = args.yamlfile
        template_file = args.templatefile.split(',')
        output_folder = args.outputfolder
        try:
            aws_updated = createBuildFile(buildfile, template_file, output_folder)
            updateYamlFile(aws_updated, buildfile)
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
