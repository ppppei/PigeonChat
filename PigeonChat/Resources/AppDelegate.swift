//
//  AppDelegate.swift
//  PigeonChat
//
//  Created by PPEI on 12/5/21.
//

import UIKit
import Firebase
import FBSDKCoreKit
import GoogleSignIn

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate, GIDSignInDelegate {
    
    
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        
        FirebaseApp.configure()
        
        ApplicationDelegate.shared.application(
            application,
            didFinishLaunchingWithOptions: launchOptions
        )
        
        GIDSignIn.sharedInstance()?.clientID = FirebaseApp.app()?.options.clientID
        GIDSignIn.sharedInstance()?.delegate = self
        //
        return true
    }
    
    func application(
        _ app: UIApplication,
        open url: URL,
        options: [UIApplication.OpenURLOptionsKey : Any] = [:]
    ) -> Bool {
        
        ApplicationDelegate.shared.application(
            app,
            open: url,
            sourceApplication: options[UIApplication.OpenURLOptionsKey.sourceApplication] as? String,
            annotation: options[UIApplication.OpenURLOptionsKey.annotation]
        )
        return GIDSignIn.sharedInstance().handle(url)
    }
    //after sign in pass what project
    func sign(_ signIn: GIDSignIn!, didSignInFor user: GIDGoogleUser!, withError error: Error!) {
        guard error == nil else{
            if let error = error{
                print ("failed to sign in with Google: \(error)")
            }
            return
        }
        
        guard let user = user else {
            return
        }
        
        print("Did sign in with Google: \(user)")
        
        guard let email = user.profile.email,
              let firstName = user.profile.givenName,
              let lastName = user.profile.familyName else {
                  return
              }
        
        UserDefaults.standard.set(email, forKey: "email")
        UserDefaults.standard.set(("\(firstName)\(lastName)"), forKey: "name")
        //save the email because we can you the email to query out their image
        
        DatabaseManager.shared.userExists(with: email, completion: { exists in
            if !exists{
                //insert into database
                let chatUser = ChatAppUser(firstName: firstName,
                                           lastName: lastName,
                                           emailAddress: email)
                DatabaseManager.shared.insertUser(with: chatUser, completion: {success in
                    if success{
                        //uploadImage
                        //check if google picture acutally exists
                        
                        if user.profile.hasImage{
                            guard let url = user.profile.imageURL(withDimension: 200)else{
                                return
                            }
                            
                            URLSession.shared.dataTask(with: url, completionHandler: { data, _, _ in
                                
                                guard let data = data else{
                                    return
                                }
                                
                                let fileName = chatUser.profilePictureFileName
                                StorageManager.shared.uploadProfilePicture(with: data, filename: fileName, completion: {result in
                                    switch result{
                                    case .success(let downloadUrl):
                                        UserDefaults.standard.set(downloadUrl, forKey: "profile_picture_url")
                                        print(downloadUrl)
                                    case .failure(let error):
                                        print("Storage manage error: \(error)")
                                    }
                                })
                            }).resume()
                            
                            
                        }
                        
                    }
                })
            }
        })
        
        guard let authentication = user.authentication else {
            
            
            print("Missing auth object off of google user")
            return
            
        }
        let credential = GoogleAuthProvider.credential(withIDToken: authentication.idToken,
                                                       accessToken: authentication.accessToken)
        
        FirebaseAuth.Auth.auth().signIn(with: credential, completion: { authResult, error in
            guard authResult != nil, error == nil else{
                print("failed to log in with google credential.")
                return
            }
            print("Signed in with google cred.")
            NotificationCenter.default.post(name: .didLogInNotification, object: nil)// tell the notification to dismiss after signed in
        })
    }
    //after disconnect
    func sign(_ signIn: GIDSignIn!, didDisconnectWith user: GIDGoogleUser!, withError: Error!){
        //Perform any operations wehen the user disconnects from app here.
        print("Google User Was Disconnected")
    }
    
    func applicationWillTerminate(_ application: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey : Any]) {
        
    }
    
}

