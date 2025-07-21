import moment from 'moment-timezone';
import { MonthTrans } from '../model/month_trans.model.js';

    const getMonthTrans = async (req, res) => {
        const { attcode } = req.params;

        const data = await MonthTrans.findAll({
            where: {
                attcode: attcode
            }
        });

        console.log('attcode',typeof attcode);

        res.status(200).json({ message: "Month Trans fetched successfully", data: data });
    }

    export { getMonthTrans }