import {getAllLeaves} from '../controller/leaveTypes.controller.js';
import { Router } from 'express';

const router = Router();

router.route('/list').get(getAllLeaves);

export default router;