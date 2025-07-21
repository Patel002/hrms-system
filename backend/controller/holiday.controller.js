import Holiday from "../model/holiday.model.js";
import { Op,fn,col,where } from "sequelize";

const getAllHoliday = async(req, res) => {
    try {

        const currentYear = new Date().getFullYear();

        // console.log(currentYear);

        const holiday = await Holiday.findAll({
            where: 
                where(fn('YEAR', col('from_date')), currentYear)
        });
        res.json(holiday);
    } catch (error) {
        console.error(error);
        res.status(500).json({ message: "Internal server error" });
    }
}

export {
    getAllHoliday
}