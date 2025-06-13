import moment from 'moment-timezone';
import { MonthTrans } from '../model/month_trans.model.js';

const getMonthTrans = async (req, res) => {
    const { emp_id } = req.params;

    const data = await MonthTrans.findAll({
        where: {
            emp_id: emp_id
        }
    });
    res.status(200).json({ message: "Month Trans fetched successfully", data: data });
}

export { getMonthTrans }