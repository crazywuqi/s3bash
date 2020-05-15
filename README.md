# s3bash
本人平常开发时，爱用postman，postman支持aws v4签名认证，不支持v2。 
故自己搞了一个类似postman api访问s3 server的小脚本  
  
Usage: ./s3bash.sh HTTP-METHOD URL [options...]  
 -H "k1:v1" -H "k2:v2"   
 -O save_http_response_body_to_file  
 --body-binary=localfile  
 --body-raw=xxx  
 #--body-form-urlencode="k1:v1" --body-form-urlencode="k2:v2"   
 #--body-form-text="k1:v1" --body-form-file="k2:file"  
 -a access_key   
 -s secret_key   
 -e easy out  
 -h help  

GET  
s3bash.sh GET http://10.10.10.10:8888/bucket1/obj1 -O obj1  
s3bash.sh GET http://bucket2.endpoint/obj2 -O obj2  
  
PUT  
s3bash.sh PUT http://localhost:8000/testbucket/aaa_obj1 --body-binary=localfile  


