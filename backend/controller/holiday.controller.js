import Holiday from "../model/holiday.model.js";

const getAllHoliday = async(req, res) => {
    try {
        const holiday = await Holiday.findAll();
        res.json(holiday);
    } catch (error) {
        console.error(error);
        res.status(500).json({ message: "Internal server error" });
    }
}

export {
    getAllHoliday
}