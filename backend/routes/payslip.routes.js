import { getPaySlipInformation } from "../controller/payslip.controller.js";
import { Router } from "express";

const router = Router();

router.route('/payslip').get(getPaySlipInformation);

export default router;