# Python part
In the python module we generate the zip file for AWS Lambda that includes the needed pip packages and the latest python code. Also later we will focus in use container images instead for zip files.

For Zip file Lambda version:
first create `venv`:
```
cd python
python3 -m venv venv
source venv/bin/activate
```

Once activated the venv, install dependencies from requirements.txt inside your venv:
`pip install -r requirements.txt`


Later, locate yourself in the folder `/python` and package all the dependencies from there, and zip it (the zip file we move it inside the Terraform folder, in order to later can be taken to create the infrestructure):
```
pip install --target package_to_zip -r requirements.txt
cp index.py package_to_zip/
cd package_to_zip
zip -r ../../terraform/lambda.zip .
cd ..
```



# Terraform part

## Testing deployed Lambda
