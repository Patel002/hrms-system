import {
    getAllHoliday
} from "../controller/holiday.controller.js";
import { Router } from "express";

const router = Router();

router.route('/holiday').get(getAllHoliday);

export default router;