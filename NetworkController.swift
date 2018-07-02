import UIKit

class NetworkController: NSObject {
    /* ***********************************
     *
     *  VARIABLES
     *
     * ***********************************/
    var UrlLogin: String
    var Token: String
    var Username: String
    var Errors: [String]
    /* ***********************************
     *
     *  INIT, constructor
     *
     * ***********************************/
    init(url: String) {
        Token = ""
        Username = ""
        UrlLogin = url
        Errors = []
    }
    /* ***********************************
     *
     *  GET TOKEN FROM LOGIN
     *
     * ***********************************/
    func getTokenFromLogin(username: String, password: String, completion: @escaping (Bool) -> Void)
    {
        network.makeAPIcall(urlString: UrlLogin, postString: "LoginName="+username+"&Password="+password)
        {
            (result: [Dictionary<String,Any>]) in
            let returnCode = result[0]["Status"] as? String
            let authCode = "Authenticated"
            
            if( returnCode == authCode)
            {
                self.Username = username
                self.Token = (result[0]["AccessToken"] ?? "error token") as! String
                completion(true)
            }
            else
            {
                completion(false)
            }
        }
    }
    /* ***********************************
     *
     *  MAKE API CALL
     *
     * ***********************************/
    func makeAPIcall(method: String = "post", urlString: String, postString: String = "", headers: [String:String] = [String:String](), images: [UIImage] = [], additionalPara: [[String:Any]] = [], fieldName: String = "payload", completion: @escaping ([Dictionary<String,Any>]) -> Void)
    {
        guard let url = URL(string: urlString) else 
        {
            self.Errors.append(method + " " + urlString + " " + postString + " " + headers.description + " " + "Error: cannot create URL")
            completion([])
            return
        }
        var UrlRequest = URLRequest(url: url)
        
        UrlRequest.httpMethod = method.uppercased()
        
        for header in headers
        {
            UrlRequest.setValue(header.value, forHTTPHeaderField: header.key)
        }
        if(method.lowercased() == "post")
        {
            if(images.count > 0 || additionalPara.count > 0)
            {
                let boundary = "-----------------212312123"
                UrlRequest.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
                UrlRequest.httpBody = createBodyWithParameters(parameters: additionalPara, filePathKey: "file", images: images, boundary: boundary, nameField: fieldName) as Data
            }
            else //without file and additional para
            {
                let dataPost = postString.data(using: .utf8)
                UrlRequest.httpBody = dataPost
            }
        }
        
        let session = URLSession.shared
        
        let task = session.dataTask(with: UrlRequest) 
        {
            (data, response, error) in
            
            guard error == nil else 
            {
                self.Errors.append(method + " " + urlString + " " + postString + " " + headers.description + " " + "Error calling POST on url ")
                completion([])
                return
            }
            
            guard let responseData = data else 
            {
                self.Errors.append(method + " " + urlString + " " + postString + " " + headers.description + " " + "Error did not receive data")
                completion([])
                return
            }
            // parse the result as JSON, since that's what the API provides
            do 
            {
                guard let received = try JSONSerialization.jsonObject(with: responseData, options: []) as? [Dictionary<String,Any>] else
                {
                    //single json returned case
                    guard let dataArray = try JSONSerialization.jsonObject(with: responseData, options: []) as? Dictionary<String,Any>
                    else
                    {
                        self.Errors.append(method + " " + urlString + " " + postString + " " + headers.description + " " + "Could not get Json form response")
                        return
                    }
                    completion([dataArray])
                    return
                }
                completion(received)
            }
            catch  
            {
                self.Errors.append(method + " " + urlString + " " + postString + " " + headers.description + " " + (String(data: responseData, encoding: String.Encoding.utf8) ?? "data format error"))
                completion([])
                return
            }
        }
        task.resume()
    }

    /* ***********************************
     *
     *  CREATE BODY WITH PARAMETRES
     *
     * ***********************************/
    private func createBodyWithParameters(parameters: [[String: Any]] = [], filePathKey: String?, images: [UIImage] = [], boundary: String, nameField: String = "payload") -> NSData 
    {
        let body = NSMutableData();
        
        if (parameters.count > 0)
        {
            //paramtres as JSON
            body.appendString(string: "--\(boundary)\r\n")
            let jsonData = try! JSONSerialization.data(withJSONObject: parameters, options: [])
            body.appendString(string: "Content-Disposition: form-data; name=\"\(nameField)\"\r\n\r\n")
            let reqJSONStr = String(data: jsonData, encoding: .utf8)
            body.appendString(string: reqJSONStr!)
            body.appendString(string: "\r\n")
        }

        var i = 1
        let mimetype = "image/jpg"
        var fileData = Data()
        
        for image in images
        {
            fileData = UIImageJPEGRepresentation(image, 0.5)!
            body.appendString(string: "--\(boundary)\r\n")
            body.appendString(string: "Content-Disposition: form-data; name=\"file\(i)\"; filename=\"image\(i).jpg\"\r\n")
            body.appendString(string: "Content-Type: \(mimetype)\r\n\r\n")
            body.append(fileData)
            body.appendString(string: "\r\n\r\n")

            i += 1
        }
        
        body.appendString(string: "--\(boundary)--\r\n")
        return body
    }
}

extension NSMutableData 
{
    func appendString(string: String) 
    {
        let data = string.data(using: String.Encoding.utf8, allowLossyConversion: true)
        append(data!)
    }
}
