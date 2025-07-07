import multer from 'multer';
import path from 'path';

const MAX_FILE_SIZE_MB = 10;
const MAX_FILE_SIZE_IN_BYTES = MAX_FILE_SIZE_MB*1024*1024;

const storage = multer.diskStorage({
  destination: (req, file, cb) => {
    cb(null,'../uploads/profileImage'); 
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



const leaveFileStorage = multer.diskStorage({
  destination: (req, file, cb) => {
    cb(null,'../uploads'); 
  },
  filename: (req, file, cb) => {
    const uniqueSuffix = Date.now() + '_' + (Math.random() * 1e9);
    
    cb(null, uniqueSuffix + path.extname(file.originalname));

    console.log("file",uniqueSuffix);
  },
});

const leaveFileFilter = (req, file, cb) => {
  cb(null, true); 
};


export const leaveFileUpload = multer({
  storage: leaveFileStorage,
  fileFilter: leaveFileFilter,
  limits: { fileSize: MAX_FILE_SIZE_IN_BYTES },
});


