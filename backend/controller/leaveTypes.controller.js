import {
    LeaveTypes
} from '../utils/join.js';

const getAllLeaves = async(req,res) => {
    try {
        const leaves = await LeaveTypes.findAll();
        console.log("leaves list",leaves)
        res.status(200).json(leaves);

    } catch (error) {
        console.log(error);
        req.status(500).json({
            message: "Error while getting leave types from backend"
        })
    }
}

export{
    getAllLeaves
}