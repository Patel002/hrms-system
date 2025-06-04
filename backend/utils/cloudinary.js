import { v2 as cloudinary } from 'cloudinary';
import fs from 'fs';

cloudinary.config({
    cloud_name: 'dvioe9jiv',
    api_key: '568438959988812',
    api_secret: 'Wn0yV5CEhDPkAMT8olpZ6tH0G0A',
})

const uploadOnCloudinary = async (localFilePath) => {
    try {
        if(!localFilePath) return null

        const response = await cloudinary.uploader.upload(localFilePath, {
           folder: "uploads",
           resource_type: 'raw',
           use_filename: true,
           type: 'upload'
        })
        
        console.log("File uploaded successfully",response.url, "response",response);

        fs.unlinkSync(localFilePath)
        return response;
        
    } catch (error) {
        fs.unlinkSync(localFilePath)
        return null
    }
}

export  {uploadOnCloudinary}