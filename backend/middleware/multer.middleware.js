import multer from 'multer';
import path from 'path';

const storage = multer.memoryStorage({
  destination: (req, file, cb) => {
    cb(null, '../uploads/profileImage/'); 
  },
  filename: (req, file, cb) => {
    const uniqueSuffix = Date.now() + '-' + req.params.em_id + '_' + req.body.em_username;
    
    cb(null, uniqueSuffix + path.extname(file.originalname));

    console.log("file",uniqueSuffix);
  },
});

const fileFilter = (req, file, cb) => {
  cb(null, true); 
};

export const upload = multer({
  storage: storage,
  fileFilter: fileFilter,
});

