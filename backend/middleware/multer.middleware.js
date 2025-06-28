import multer from 'multer';
import path from 'path';

const storage = multer.diskStorage({
  destination: (req, file, cb) => {
    cb(null, '../uploads/profileImage/'); 
  },
  filename: (req, file, cb) => {
    const uniqueSuffix = Date.now() + '-' + Math.round(Math.random() * 1e9);
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

